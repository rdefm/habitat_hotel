extends Node

## Drives the guest lifecycle (arrive -> match -> stay -> checkout) across
## the day's phases. Listens to Clock via EventBus; mutates GameState;
## emits EventBus.day_summary for any view (console, UI, batch tool) to
## consume. Holds no presentation logic of its own.

const DemandGenerator = preload("res://sim/demand_generator.gd")
const Matcher = preload("res://sim/matcher.gd")
const Satisfaction = preload("res://sim/satisfaction.gd")

# STAYING guests only, keyed by guest id. Dict: {id, species_id, party_size,
# nights_total, nights_remaining, room_slot_index, satisfaction, mismatch}.
var guests: Dictionary = {}
var _next_guest_id: int = 1

var _pending_arrivals: Array = []
var _ready_for_checkout: Array = []
var _day_metrics: Dictionary = {}


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
		"checkouts": 0,
		"positive_reviews": 0,
		"neutral_reviews": 0,
		"negative_reviews": 0,
	}

	for gid in _ready_for_checkout:
		_checkout_guest(gid)
	_ready_for_checkout.clear()

	_pending_arrivals = DemandGenerator.generate(GameState, Rng)
	_day_metrics["arrivals"] = _pending_arrivals.size()


func _do_midday(_day: int) -> void:
	for arrival in _pending_arrivals:
		var decision := Matcher.decide(arrival, GameState.hotel_rooms, GameState.rooms, GameState.matcher_policy)
		match decision["reason"]:
			"matched_strict":
				_admit_guest(arrival, decision["room_slot_index"], false)
				_day_metrics["matched_strict"] += 1
			"matched_mismatch":
				_admit_guest(arrival, decision["room_slot_index"], true)
				_day_metrics["matched_mismatched"] += 1
			"no_match_available":
				# Turned away because no room *type* could meet their needs (strict policy) --
				# a real service failure, so it stings reputation.
				GameState.reputation = clampi(GameState.reputation + int(GameState.balance["review"]["reputation_delta_walkaway"]), 0, 100)
				_day_metrics["walked_away_mismatch"] += 1
			"fully_booked":
				# Turned away only because every room is occupied -- being sold out isn't
				# a service failure, so this doesn't cost reputation.
				_day_metrics["walked_away_full"] += 1
	_pending_arrivals.clear()


func _do_evening(_day: int) -> void:
	pass # Meals/incidents arrive in Chunk 5; care-per-night is already folded into match-time satisfaction.


func _do_night(_day: int) -> void:
	var upkeep := 0
	for room in GameState.hotel_rooms:
		var room_type: Dictionary = GameState.rooms[room["room_type_id"]]
		upkeep += int(room_type["upkeep_per_day"])
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


func _admit_guest(arrival: Dictionary, room_slot_index: int, mismatch: bool) -> void:
	var room: Dictionary = GameState.hotel_rooms[room_slot_index]
	var room_type: Dictionary = GameState.rooms[room["room_type_id"]]
	var sat := Satisfaction.compute(arrival, room_type, GameState.hotel_amenities, GameState.balance)

	var gid := _next_guest_id
	_next_guest_id += 1
	guests[gid] = {
		"id": gid,
		"species_id": arrival["species_id"],
		"party_size": arrival["party_size"],
		"nights_total": arrival["nights_total"],
		"nights_remaining": arrival["nights_total"],
		"room_slot_index": room_slot_index,
		"satisfaction": sat,
		"mismatch": mismatch,
	}
	room["occupant"] = gid


func _checkout_guest(gid: int) -> void:
	if not guests.has(gid):
		push_error("[Sim] Tried to check out unknown guest id %d" % gid)
		return
	var g: Dictionary = guests[gid]
	var room: Dictionary = GameState.hotel_rooms[g["room_slot_index"]]
	var room_type: Dictionary = GameState.rooms[room["room_type_id"]]

	var revenue: int = int(room_type["base_rate"]) * int(g["nights_total"])
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

	room["occupant"] = null
	guests.erase(gid)
	_day_metrics["checkouts"] += 1
