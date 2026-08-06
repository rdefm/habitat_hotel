extends Node

## Drives the guest lifecycle (arrive -> queue -> seat -> stay -> checkout)
## across the day's phases. Listens to Clock via EventBus; mutates
## GameState; emits EventBus.day_summary for any view (console, UI, batch
## tool) to consume. Holds no presentation logic of its own.
##
## Seating is manual (ADR-0001, no auto-matcher): arrivals sit in
## pending_arrivals as a queryable queue of Parties, each with its own
## decaying Patience, until seat_party() -- the one and only admission path,
## called by interactive UI or a scripted autopilot alike -- seats them or
## their Patience runs out and they walk away.
##
## Staffers are freely reassignable across the four Stations (ADR-0005) via
## assign_staffer() -- GameState.stations holds the assignment, this file
## drives the effect of (un)staffing each one: Reception's Patience decay
## rate, Bellhop's check-in delay, and Housekeeping's per-Staffer cleaning
## jobs (_tick_housekeeping()/_tick_checkins()). Kitchen assignment is
## tracked but has no gated effect yet -- that lands with Dining in ticket 09.

const DemandGenerator = preload("res://sim/demand_generator.gd")
const MatchHint = preload("res://sim/match_hint.gd")
const Satisfaction = preload("res://sim/satisfaction.gd")
const Station = preload("res://sim/station.gd")

# STAYING guests only, keyed by guest id. Dict: {id, species_id, party_size,
# nights_total, nights_remaining, room_type_id, room_instance_id, satisfaction, mismatch}.
var guests: Dictionary = {}
var _next_guest_id: int = 1

# Arrived, not-yet-(fully)-seated Parties: {id, name, species_id, needs,
# likes, amenity_prefs, budget, party_size, nights_total, patience}.
# party_size shrinks as seat_party() carves off room-sized chunks (see
# ADR-0001's split-across-rooms behavior); the entry is removed once it
# reaches zero or its Patience expires. Public/queryable -- this queue *is*
# Reception's UI model, not an internal implementation detail.
var pending_arrivals: Array = []
var _next_party_id: int = 1

var _ready_for_checkout: Array = []
var _day_metrics: Dictionary = {}

# True only while Clock's current phase is MIDDAY -- the window during which
# pending_arrivals' Patience actually decays tick-by-tick (see
# _on_tick_advanced()). Arrivals sit with untouched Patience the rest of the
# day, mirroring the reference prototype's waitTime/patience fields.
var _midday_active: bool = false

# Tomorrow's arrivals, generated a phase early (at tonight's Night phase) so
# the player has a real window to react before they're queued. Day 1 has no
# "last night" to generate from, so _do_morning falls back to generating on
# the spot exactly once, when _has_forecast is still false.
var _next_day_forecast: Array = []
var _has_forecast: bool = false

# Housekeeping's in-flight jobs (ADR-0005), one per active Staffer:
# staffer_id -> {room_type_id, instance_id, ticks_remaining}. Every assigned
# Housekeeping Staffer cleans a different Room in parallel. Reassigning a
# Staffer away drops their own entry here without touching any other
# Staffer's job or the target Room's needs_cleaning -- it was already true
# and stays true, so no partial credit for an abandoned job.
var _cleaning_jobs: Dictionary = {}


func _ready() -> void:
	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.tick_advanced.connect(_on_tick_advanced)


## Clears all in-flight guest/day state. Used by the batch runner alongside
## GameState.reset_to_starting_conditions() and Clock.reset().
func reset() -> void:
	guests.clear()
	_next_guest_id = 1
	pending_arrivals.clear()
	_next_party_id = 1
	_midday_active = false
	_ready_for_checkout.clear()
	_day_metrics = _fresh_day_metrics()
	_next_day_forecast.clear()
	_has_forecast = false
	_cleaning_jobs.clear()


## Read-only lookup of a pending_arrivals entry by party_id, for UI that
## needs a Party's fields (species, needs, name, ...) without walking the
## array itself. Returns {} if no such Party is currently queued.
func pending_party(party_id: int) -> Dictionary:
	var idx := _pending_index(party_id)
	return pending_arrivals[idx] if idx != -1 else {}


## The match-hint (green/amber/none) for seating party_id into the room
## addressed by room_type_id + instance_id right now -- pure query, no
## admission. See MatchHint.classify().
func match_hint(party_id: int, room_type_id: String, instance_id: int) -> String:
	var idx := _pending_index(party_id)
	if idx == -1:
		return "none"
	var room := GameState.room_instance(room_type_id, instance_id)
	if room.is_empty():
		return "none"
	var room_stats := GameState.effective_room_stats(room)
	return MatchHint.classify(pending_arrivals[idx], room, room_stats, GameState.price_multipliers, GameState.balance.get("pricing", {}))


## The single admission path (ADR-0001): seats as much of party_id as the
## room addressed by room_type_id + instance_id can hold (its full capacity,
## or its remaining party_size if smaller), applying the existing green/
## mismatch handling. Returns false with no side effects if the hint is
## "none" or either id doesn't resolve. Any unseated remainder stays in
## pending_arrivals with its Patience unchanged -- see the class doc's note
## on split-across-rooms.
func seat_party(party_id: int, room_type_id: String, instance_id: int) -> bool:
	var idx := _pending_index(party_id)
	if idx == -1:
		return false
	var room := GameState.room_instance(room_type_id, instance_id)
	if room.is_empty():
		return false
	var room_stats := GameState.effective_room_stats(room)
	var pricing_balance: Dictionary = GameState.balance.get("pricing", {})
	var hint := MatchHint.classify(pending_arrivals[idx], room, room_stats, GameState.price_multipliers, pricing_balance)
	if hint == "none":
		return false

	var party: Dictionary = pending_arrivals[idx]
	var mismatch := hint == "amber"
	var chunk_size: int = mini(int(room_stats["capacity"]), int(party["party_size"]))
	_admit_guest(party, room_type_id, instance_id, mismatch, chunk_size)

	var metric_key := "matched_mismatched" if mismatch else "matched_strict"
	_day_metrics[metric_key] += 1

	party["party_size"] -= chunk_size
	if party["party_size"] <= 0:
		pending_arrivals.remove_at(idx)
	return true


## The single Staffer<->Station reassignment path (ADR-0005): moves
## staffer_id into station_id, dropping it from wherever it was assigned
## before. If staffer_id had an in-flight Housekeeping job and is actually
## moving to a different Station, that job is abandoned (see
## _cleaning_jobs' doc comment) without touching any other Staffer's job.
## Returns false with no effect for an unknown Staffer or Station id.
func assign_staffer(staffer_id: String, station_id: String) -> bool:
	if not GameState.staffers.has(staffer_id) or not Station.is_valid(station_id):
		return false
	if GameState.staffer_station(staffer_id) != station_id:
		_cleaning_jobs.erase(staffer_id)
	return GameState.reassign_staffer(staffer_id, station_id)


## Read-only lookup of a Housekeeping Staffer's in-flight job, for UI/tests.
## Returns {} if that Staffer isn't currently cleaning anything.
func cleaning_job(staffer_id: String) -> Dictionary:
	return _cleaning_jobs.get(staffer_id, {})


func _on_phase_changed(day: int, phase_name: String) -> void:
	_midday_active = (phase_name == "MIDDAY")
	match phase_name:
		"MORNING":
			_do_morning(day)
		"EVENING":
			_do_evening(day)
		"NIGHT":
			_do_night(day)


func _on_tick_advanced(_day: int, _tick_in_day: int) -> void:
	_tick_housekeeping()
	_tick_checkins()
	if not _midday_active:
		return
	_decay_patience()


func _do_morning(day: int) -> void:
	if not pending_arrivals.is_empty():
		push_error("[Sim] %d Party(ies) still pending at start of day %d -- Evening's safety-net expiry should have cleared the queue." % [pending_arrivals.size(), day])
		pending_arrivals.clear()

	_day_metrics = _fresh_day_metrics()

	for gid in _ready_for_checkout:
		_checkout_guest(gid)
	_ready_for_checkout.clear()

	var arrivals: Array
	if _has_forecast:
		arrivals = _next_day_forecast
		_next_day_forecast = []
		_has_forecast = false
	else:
		# Day 1 only -- every later day's arrivals were already forecast last Night.
		arrivals = DemandGenerator.generate(GameState, Rng)

	for arrival in arrivals:
		pending_arrivals.append(_new_party(arrival))

	_day_metrics["arrivals"] = pending_arrivals.size()
	for party in pending_arrivals:
		var species_id: String = party["species_id"]
		_day_metrics["arrival_species"][species_id] = int(_day_metrics["arrival_species"].get(species_id, 0)) + 1


## Zeroed day-metrics shape, shared by reset() (so seat_party() has
## somewhere safe to accumulate into even before this day's first Morning
## has run -- real play never calls it that early since pending_arrivals is
## always empty until Morning populates it, but tests exercise seat_party()
## directly against a hand-built Party) and _do_morning() (the real per-day
## reset).
func _fresh_day_metrics() -> Dictionary:
	return {
		"day": GameState.day,
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


func _new_party(arrival: Dictionary) -> Dictionary:
	var party := arrival.duplicate()
	party["id"] = _next_party_id
	_next_party_id += 1
	party["patience"] = float(GameState.balance["patience"]["start"])
	return party


func _pending_index(party_id: int) -> int:
	for i in range(pending_arrivals.size()):
		if int(pending_arrivals[i]["id"]) == party_id:
			return i
	return -1


## An unstaffed Reception Station burns Patience faster (ADR-0005) -- a flat
## data-driven multiplier on presence, not scaled by Skill (mirrors the
## reference prototype's RECEPTION_UNSTAFFED_PATIENCE_MULTIPLIER).
func _decay_patience() -> void:
	var decay: float = float(GameState.balance["patience"]["decay_per_tick"])
	if not GameState.is_station_staffed("reception"):
		decay *= float(_station_balance("reception").get("unstaffed_patience_multiplier", 1.0))
	for party in pending_arrivals:
		party["patience"] = maxf(0.0, float(party["patience"]) - decay)

	var expired: Array = pending_arrivals.filter(func(p): return float(p["patience"]) <= 0.0)
	for party in expired:
		pending_arrivals.erase(party)
		_walk_away(party)


func _walk_away(party: Dictionary) -> void:
	var pricing_balance: Dictionary = GameState.balance.get("pricing", {})
	var reason := MatchHint.walk_away_reason(party, GameState.hotel_rooms, _effective_stats_by_key(), GameState.price_multipliers, pricing_balance)
	match reason:
		"no_match_available":
			# A real service failure (no eligible room ever existed, or one
			# did and simply never got tapped in time) -- stings reputation.
			GameState.reputation = clampi(GameState.reputation + int(GameState.balance["review"]["reputation_delta_walkaway"]), 0, 100)
			_day_metrics["walked_away_mismatch"] += 1
		"fully_booked":
			# Turned away only because every room is occupied -- being sold out isn't
			# a service failure, so this doesn't cost reputation.
			_day_metrics["walked_away_full"] += 1
		"too_expensive":
			# Turned away by the player's own pricing choice -- a lost sale, not a
			# service failure, so this doesn't cost reputation either.
			_day_metrics["walked_away_too_expensive"] += 1
	_track_turned_away(party)
	EventBus.guest_turned_away.emit(party["name"], party["species_id"], reason)


func _track_turned_away(party: Dictionary) -> void:
	var species_id: String = party["species_id"]
	_day_metrics["turned_away_species"][species_id] = int(_day_metrics["turned_away_species"].get(species_id, 0)) + 1


## Base room type stats merged with each instance's purchased upgrades,
## keyed by MatchHint.room_key() (room_type_id + instance_id). Computed
## fresh whenever needed since upgrades can be bought between phases while
## the clock is paused for a menu.
func _effective_stats_by_key() -> Dictionary:
	var out: Dictionary = {}
	for room in GameState.hotel_rooms:
		out[MatchHint.room_key(room)] = GameState.effective_room_stats(room)
	return out


## data/balance.json's stations.<station_id> tuning block, or {} if absent.
func _station_balance(station_id: String) -> Dictionary:
	return GameState.balance.get("stations", {}).get(station_id, {})


## Meals/incidents arrive in Chunk 5; care-per-night is already folded into
## seat-time satisfaction. Housekeeping's turnover no longer happens here in
## a single bulk sweep -- see _tick_housekeeping(), which drains dirty Rooms
## continuously across the whole day as each assigned Staffer frees up.
##
## Any pending_arrivals entry still here despite Midday's tick-by-tick decay
## (Patience's configured start is well under Midday's tick count, so this
## should never actually fire) is force-expired as a defensive safety net --
## nothing should be able to carry an unresolved Party across a day boundary.
func _do_evening(_day: int) -> void:
	for party in pending_arrivals:
		_walk_away(party)
	pending_arrivals.clear()


## Parallel per-Staffer cleaning (ADR-0005): every Housekeeping Staffer not
## already mid-job claims the next dirty, unclaimed Room and works it down
## over a Skill-dependent number of ticks (data/balance.json's
## stations.housekeeping.clean_ticks_by_skill). An unstaffed Housekeeping
## Station simply never drains the queue -- dirty Rooms stay dirty
## indefinitely, same as the reference prototype -- so leaving the Station
## empty has a real, visible cost rather than a deadline that bails it out.
func _tick_housekeeping() -> void:
	var clean_ticks_by_skill: Dictionary = _station_balance("housekeeping").get("clean_ticks_by_skill", {})
	var default_ticks: int = int(_station_balance("housekeeping").get("default_clean_ticks", 32))

	for staffer_id in GameState.station_staffers("housekeeping"):
		if _cleaning_jobs.has(staffer_id):
			continue
		var room := _next_dirty_unclaimed_room()
		if room.is_empty():
			continue
		var skill: int = int(GameState.staffers[staffer_id]["skills"]["housekeeping"])
		var ticks: int = int(clean_ticks_by_skill.get(str(skill), default_ticks))
		_cleaning_jobs[staffer_id] = {
			"room_type_id": room["room_type_id"],
			"instance_id": int(room["instance_id"]),
			"ticks_remaining": ticks,
		}

	for staffer_id in _cleaning_jobs.keys().duplicate():
		var job: Dictionary = _cleaning_jobs[staffer_id]
		job["ticks_remaining"] = int(job["ticks_remaining"]) - 1
		if job["ticks_remaining"] > 0:
			continue
		var room := GameState.room_instance(job["room_type_id"], job["instance_id"])
		if not room.is_empty():
			room["needs_cleaning"] = false
			EventBus.room_cleaned.emit(room["room_type_id"], int(room["instance_id"]))
		_cleaning_jobs.erase(staffer_id)


## The first dirty Room (in hotel_rooms order) no in-flight cleaning job is
## already targeting -- what a Housekeeping Staffer who just freed up picks
## up next. Returns {} if there's nothing left to claim.
func _next_dirty_unclaimed_room() -> Dictionary:
	var claimed: Dictionary = {}
	for job in _cleaning_jobs.values():
		claimed[MatchHint.room_key(job)] = true
	for room in GameState.hotel_rooms:
		if room.get("needs_cleaning", false) and not claimed.has(MatchHint.room_key(room)):
			return room
	return {}


## Bellhop coverage is evaluated once, at the moment of admission (mirrors
## the reference prototype): a staffed Bellhop moves a guest straight in, an
## unstaffed one leaves the Room "checking_in" for a flat data-driven delay
## (stations.bellhop.unstaffed_checkin_delay_ticks). Presence-only, same as
## Reception's Patience multiplier -- Skill doesn't modulate this.
func _start_checkin(room: Dictionary) -> void:
	if GameState.is_station_staffed("bellhop"):
		room["checking_in"] = false
		room["checkin_ticks_remaining"] = 0
		return
	room["checking_in"] = true
	room["checkin_ticks_remaining"] = int(_station_balance("bellhop").get("unstaffed_checkin_delay_ticks", 0))


func _tick_checkins() -> void:
	for room in GameState.hotel_rooms:
		if not room.get("checking_in", false):
			continue
		room["checkin_ticks_remaining"] = int(room["checkin_ticks_remaining"]) - 1
		if room["checkin_ticks_remaining"] <= 0:
			room["checking_in"] = false
			room["checkin_ticks_remaining"] = 0


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


func _admit_guest(party: Dictionary, room_type_id: String, instance_id: int, mismatch: bool, chunk_size: int) -> void:
	var room: Dictionary = GameState.room_instance(room_type_id, instance_id)
	var room_stats := GameState.effective_room_stats(room)
	var sat := Satisfaction.compute(party, room_stats, GameState.hotel_amenities, GameState.balance)

	var gid := _next_guest_id
	_next_guest_id += 1
	guests[gid] = {
		"id": gid,
		"name": party["name"],
		"species_id": party["species_id"],
		"party_size": chunk_size,
		"nights_total": party["nights_total"],
		"nights_remaining": party["nights_total"],
		"room_type_id": room_type_id,
		"room_instance_id": instance_id,
		"satisfaction": sat,
		"mismatch": mismatch,
	}
	room["occupant"] = gid
	room["occupant_name"] = party["name"]
	room["occupant_species_id"] = party["species_id"]
	room["occupant_mismatch"] = mismatch
	_start_checkin(room)
	EventBus.guest_seated.emit(party["name"], party["species_id"], room_type_id, instance_id, mismatch)


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
