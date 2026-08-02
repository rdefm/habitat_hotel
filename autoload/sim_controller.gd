extends Node

## Drives the guest lifecycle (arrive -> match -> stay -> checkout) across
## the day's phases. Listens to Clock via EventBus; mutates GameState;
## emits EventBus.day_summary for any view (console, UI, batch tool) to
## consume. Holds no presentation logic of its own.

const DemandGenerator = preload("res://sim/demand_generator.gd")
const Matcher = preload("res://sim/matcher.gd")
const Satisfaction = preload("res://sim/satisfaction.gd")

# STAYING guests only, keyed by guest id. Dict: {id, species_id, party_size,
# nights_total, nights_remaining, room_type_id, room_instance_id, satisfaction, mismatch}.
var guests: Dictionary = {}
var _next_guest_id: int = 1

var _pending_arrivals: Array = []
var _ready_for_checkout: Array = []
var _day_metrics: Dictionary = {}

# Tomorrow's arrivals, generated a phase early (at tonight's Night phase) so
# the player has a real window to react before they're matched. Day 1 has no
# "last night" to generate from, so _do_morning falls back to generating on
# the spot exactly once, when _has_forecast is still false.
var _next_day_forecast: Array = []
var _has_forecast: bool = false


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)


## Clears all in-flight guest/day state. Used by the batch runner alongside
## GameState.reset_to_starting_conditions() and Clock.reset().
func reset() -> void:
	guests.clear()
	_next_guest_id = 1
	_pending_arrivals.clear()
	_ready_for_checkout.clear()
	_day_metrics = {}
	_next_day_forecast.clear()
	_has_forecast = false


func _on_phase_changed(day: int, phase_name: String) -> void:
	match phase_name:
		"MORNING":
			_do_morning(day)
		"MIDDAY":
			_do_midday(day)
		"EVENING":
			_do_evening(day)
		"NIGHT":
			_do_night(day)


func _do_morning(day: int) -> void:
	if not _pending_arrivals.is_empty():
		push_error("[Sim] %d guest(s) still pending match at start of day %d -- matcher did not resolve them all last Midday." % [_pending_arrivals.size(), day])
		_pending_arrivals.clear()

	_day_metrics = {
		"day": day,
		"cash_start": GameState.cash,
		"arrivals": 0,
		"matched_strict": 0,
		"matched_mismatched": 0,
		"walked_away_mismatch": 0,
		"walked_away_full": 0,
		"walked_away_too_expensive": 0,
		"checkouts": 0,
		"positive_reviews": 0,
		"neutral_reviews": 0,
		"negative_reviews": 0,
		"arrival_species": {},
		"turned_away_species": {},
	}

	for gid in _ready_for_checkout:
		_checkout_guest(gid)
	_ready_for_checkout.clear()

	if _has_forecast:
		_pending_arrivals = _next_day_forecast
		_next_day_forecast = []
		_has_forecast = false
	else:
		# Day 1 only -- every later day's arrivals were already forecast last Night.
		_pending_arrivals = DemandGenerator.generate(GameState, Rng)

	_day_metrics["arrivals"] = _pending_arrivals.size()
	for arrival in _pending_arrivals:
		var species_id: String = arrival["species_id"]
		_day_metrics["arrival_species"][species_id] = int(_day_metrics["arrival_species"].get(species_id, 0)) + 1


func _do_midday(_day: int) -> void:
	var pricing_balance: Dictionary = GameState.balance.get("pricing", {})
	var room_stats_by_key := _effective_stats_by_key()
	for arrival in _pending_arrivals:
		var decision := Matcher.decide(arrival, GameState.hotel_rooms, room_stats_by_key, GameState.matcher_policy, GameState.price_multipliers, pricing_balance)
		match decision["reason"]:
			"matched_strict":
				_admit_guest(arrival, decision["room_type_id"], decision["instance_id"], false)
				_day_metrics["matched_strict"] += 1
			"matched_mismatch":
				_admit_guest(arrival, decision["room_type_id"], decision["instance_id"], true)
				_day_metrics["matched_mismatched"] += 1
			"no_match_available":
				# Turned away because no room *type* could meet their needs (strict policy) --
				# a real service failure, so it stings reputation.
				GameState.reputation = clampi(GameState.reputation + int(GameState.balance["review"]["reputation_delta_walkaway"]), 0, 100)
				_day_metrics["walked_away_mismatch"] += 1
				_track_turned_away(arrival)
				EventBus.guest_turned_away.emit(arrival["name"], arrival["species_id"], decision["reason"])
			"fully_booked":
				# Turned away only because every room is occupied -- being sold out isn't
				# a service failure, so this doesn't cost reputation.
				_day_metrics["walked_away_full"] += 1
				_track_turned_away(arrival)
				EventBus.guest_turned_away.emit(arrival["name"], arrival["species_id"], decision["reason"])
			"too_expensive":
				# Turned away by the player's own pricing choice -- a lost sale, not a
				# service failure, so this doesn't cost reputation either.
				_day_metrics["walked_away_too_expensive"] += 1
				_track_turned_away(arrival)
				EventBus.guest_turned_away.emit(arrival["name"], arrival["species_id"], decision["reason"])
	_pending_arrivals.clear()


func _track_turned_away(arrival: Dictionary) -> void:
	var species_id: String = arrival["species_id"]
	_day_metrics["turned_away_species"][species_id] = int(_day_metrics["turned_away_species"].get(species_id, 0)) + 1


## Base room type stats merged with each instance's purchased upgrades,
## keyed by Matcher.room_key() (room_type_id + instance_id). Computed fresh
## each Midday/Night since upgrades can be bought between phases while the
## clock is paused for a menu.
func _effective_stats_by_key() -> Dictionary:
	var out: Dictionary = {}
	for room in GameState.hotel_rooms:
		out[Matcher.room_key(room)] = GameState.effective_room_stats(room)
	return out


## Meals/incidents arrive in Chunk 5; care-per-night is already folded into
## match-time satisfaction. This phase also doubles as the housekeeping
## turnover point: any room left dirty by a Morning checkout is cleaned here,
## so it's unavailable to Midday's matcher for the rest of that day and
## ready again next day.
func _do_evening(_day: int) -> void:
	for room in GameState.hotel_rooms:
		if room.get("needs_cleaning", false):
			room["needs_cleaning"] = false
			EventBus.room_cleaned.emit(room["room_type_id"], int(room["instance_id"]))


func _do_night(day: int) -> void:
	var upkeep := 0
	for room in GameState.hotel_rooms:
		upkeep += int(GameState.effective_room_stats(room)["upkeep_per_day"])
	var wage := int(GameState.balance["costs"]["staff_wage_per_day"])
	GameState.cash -= (upkeep + wage)
	_day_metrics["upkeep_cost"] = upkeep
	_day_metrics["wage_cost"] = wage

	for gid in guests.keys():
		var g: Dictionary = guests[gid]
		g["nights_remaining"] -= 1
		if g["nights_remaining"] <= 0:
			_ready_for_checkout.append(gid)

	var total_sat := 0.0
	for gid in guests.keys():
		total_sat += guests[gid]["satisfaction"]
	_day_metrics["avg_satisfaction"] = (total_sat / guests.size()) if not guests.is_empty() else 0.0

	var occupied := 0
	for room in GameState.hotel_rooms:
		if room["occupant"] != null:
			occupied += 1
	_day_metrics["occupancy_rate"] = (float(occupied) / float(GameState.hotel_rooms.size())) if not GameState.hotel_rooms.is_empty() else 0.0

	_day_metrics["cash_end"] = GameState.cash
	_day_metrics["cash_delta"] = GameState.cash - int(_day_metrics["cash_start"])
	_day_metrics["hearts"] = GameState.hearts
	_day_metrics["reputation"] = GameState.reputation

	EventBus.day_summary.emit(_day_metrics.duplicate())

	_next_day_forecast = DemandGenerator.generate(GameState, Rng)
	_has_forecast = true
	EventBus.forecast_ready.emit(day + 1, _next_day_forecast.duplicate())


func _admit_guest(arrival: Dictionary, room_type_id: String, instance_id: int, mismatch: bool) -> void:
	var room: Dictionary = GameState.room_instance(room_type_id, instance_id)
	var room_stats := GameState.effective_room_stats(room)
	var sat := Satisfaction.compute(arrival, room_stats, GameState.hotel_amenities, GameState.balance)

	var gid := _next_guest_id
	_next_guest_id += 1
	guests[gid] = {
		"id": gid,
		"name": arrival["name"],
		"species_id": arrival["species_id"],
		"party_size": arrival["party_size"],
		"nights_total": arrival["nights_total"],
		"nights_remaining": arrival["nights_total"],
		"room_type_id": room_type_id,
		"room_instance_id": instance_id,
		"satisfaction": sat,
		"mismatch": mismatch,
	}
	room["occupant"] = gid
	room["occupant_name"] = arrival["name"]
	room["occupant_species_id"] = arrival["species_id"]
	room["occupant_mismatch"] = mismatch
	EventBus.guest_seated.emit(arrival["name"], arrival["species_id"], room_type_id, instance_id, mismatch)


func _checkout_guest(gid: int) -> void:
	if not guests.has(gid):
		push_error("[Sim] Tried to check out unknown guest id %d" % gid)
		return
	var g: Dictionary = guests[gid]
	var room: Dictionary = GameState.room_instance(g["room_type_id"], g["room_instance_id"])
	var room_stats := GameState.effective_room_stats(room)
	var species: Dictionary = GameState.species[g["species_id"]]

	var nightly_rate: float = float(room_stats["base_rate"]) * GameState.price_multiplier_for(room["room_type_id"])
	var revenue: int = int(round(nightly_rate * int(g["nights_total"])))
	GameState.cash += revenue

	var sat: float = g["satisfaction"]
	GameState.hearts += Satisfaction.hearts_for(sat, GameState.balance)

	var review := Satisfaction.review_for(sat, GameState.balance)
	GameState.reputation = clampi(GameState.reputation + Satisfaction.reputation_delta_for_review(review, GameState.balance), 0, 100)
	match review:
		"positive":
			_day_metrics["positive_reviews"] += 1
		"negative":
			_day_metrics["negative_reviews"] += 1
		_:
			_day_metrics["neutral_reviews"] += 1

	var flavor_lines: Array = species.get("flavor_lines", [])
	var flavor_line: String = flavor_lines[Rng.randi_range(0, flavor_lines.size() - 1)] if not flavor_lines.is_empty() else ""
	EventBus.review_posted.emit({
		"day": GameState.day,
		"guest_name": g["name"],
		"species_id": g["species_id"],
		"species_name": species["name"],
		"review": review,
		"satisfaction": sat,
		"revenue": revenue,
		"flavor_line": flavor_line,
	})

	EventBus.guest_checked_out.emit(g["name"], g["species_id"], g["room_type_id"], g["room_instance_id"])

	room["occupant"] = null
	room["occupant_name"] = null
	room["occupant_species_id"] = null
	room["occupant_mismatch"] = false
	room["needs_cleaning"] = true
	guests.erase(gid)
	_day_metrics["checkouts"] += 1
	EventBus.room_marked_dirty.emit(g["room_type_id"], g["room_instance_id"])
