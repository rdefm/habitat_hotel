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
## jobs (_tick_housekeeping()/_tick_checkins()). Kitchen gates the Terrace's
## breakfast service (ADR-0003, ticket 09): the Terrace itself is a fixed
## structure present from Day 1, no build/unlock required, exactly like
## Reception -- see _populate_breakfast_queue()/_tick_breakfast(). Kitchen
## also gates the Terrace's Evening Walk-in Diner service (ticket 10), on a
## higher Skill threshold than breakfast and with its own Patience-timered
## queue independent of the Room-booking arrivals -- see
## _populate_walkin_queue()/_tick_dinner()/_decay_walkin_patience(). A
## Staffer can only work one Kitchen job at a time, so breakfast and dinner
## claims share the busy-check _kitchen_busy(). A served Walk-in Diner feeds
## Hearts/Reputation the same way a good Checkout does (ticket 11,
## ADR-0003) -- see _serve_walkin_diner(), called from _tick_dinner() just
## before the served entry leaves walkin_queue; an unserved one walking away
## from Patience expiry costs Reputation the same way a lost Room-booking
## Party's walk-away does -- see _decay_walkin_patience(). A room guest can
## opt into a dinner add-on as part of being seated (ticket 12) -- seat_party()
## takes a dinner_addon flag, and every currently-opted-in guest folds into
## the same Evening walkin_queue/Kitchen-skill gating/Reputation-Hearts path
## as a true Walk-in Diner, tagged with a guest_id back-reference so its
## outcome can clear the opt-in on both the guest record and the Room card --
## see _queue_room_guest_addons()/_resolve_room_guest_addon(). A purchased
## Terrace upgrade (ticket 13, ADR-0003, GameState.effective_terrace_stats())
## feeds three Dining outcomes the same way a Room upgrade feeds a stay: its
## satisfaction_bonus adds directly into _serve_walkin_diner()'s
## Satisfaction.compute_dining() score, its capacity_delta widens the Walk-in
## count range _populate_walkin_queue() draws from, and its upkeep_delta
## folds into _do_night()'s nightly upkeep alongside every Room's.

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

# Terrace breakfast queue (ADR-0003): {id, guest_id, room_type_id,
# instance_id, species_id, party_size} for every currently-occupied Room's
# guest, rebuilt from scratch each Morning by _populate_breakfast_queue() --
# any entry left over from a prior Morning is dropped, not carried forward.
# Public/queryable, same as pending_arrivals.
var breakfast_queue: Array = []
var _next_breakfast_entry_id: int = 1

# Breakfast's in-flight jobs (ADR-0005), one per active Kitchen Staffer:
# staffer_id -> {entry_id, ticks_remaining}. Mirrors _cleaning_jobs' shape --
# every assigned Kitchen Staffer at/above the breakfast skill threshold
# serves a different queued guest in parallel; a Staffer below the threshold
# never claims a job at all. Reassigning a Staffer away drops their own
# entry here (see assign_staffer()) without removing the queue entry itself
# -- an interrupted guest just goes back to waiting, same as an interrupted
# Housekeeping job leaves the Room dirty.
var _breakfast_jobs: Dictionary = {}

# True only while Clock's current phase is EVENING -- the window during
# which Walk-in Diners actually arrive and their Patience decays
# tick-by-tick (see _on_tick_advanced()), mirroring _midday_active's role
# for pending_arrivals.
var _evening_active: bool = false

# The Terrace's Evening Walk-in Diner queue (ticket 10): {id, name,
# species_id, party_size, patience}, one entry per Walk-in Diner. Populated
# fresh each Evening by _populate_walkin_queue() -- unlike breakfast_queue's
# guest-per-occupied-Room source, the count and Species mix are drawn from
# data/balance.json's dining.walkin_* tuning (Species pick biased toward
# GameState.daily_special) -- see DemandGenerator.pick_walkin_species().
# Public/queryable, same as pending_arrivals/breakfast_queue.
var walkin_queue: Array = []
var _next_walkin_id: int = 1

# Dinner's in-flight jobs (ADR-0005), one per active Kitchen Staffer at/above
# stations.kitchen.dinner_min_skill: staffer_id -> {entry_id,
# ticks_remaining}. Mirrors _breakfast_jobs' shape exactly; kept as a
# separate dict (rather than folded into _breakfast_jobs) so breakfast and
# dinner service can be reasoned about independently even though a Staffer
# can only ever be claimed by one of the two at a time (_kitchen_busy()).
var _dinner_jobs: Dictionary = {}


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
	breakfast_queue.clear()
	_next_breakfast_entry_id = 1
	_breakfast_jobs.clear()
	_evening_active = false
	walkin_queue.clear()
	_next_walkin_id = 1
	_dinner_jobs.clear()


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
##
## dinner_addon (ticket 12, ADR-0003): a Party can opt into a dinner add-on
## "for their stay" -- a Party-level choice, not a per-Room-chunk one -- so
## passing true here sticks to the Party dict (party["dinner_addon"]) and
## carries automatically to every later seat_party() call against the same
## party_id, e.g. an oversized Party's remaining chunks after a split. Once
## seated, the guest carries the opt-in until the Evening dinner queue
## resolves it -- see _populate_walkin_queue()/_resolve_room_guest_addon().
func seat_party(party_id: int, room_type_id: String, instance_id: int, dinner_addon: bool = false) -> bool:
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
	if dinner_addon:
		party["dinner_addon"] = true
	var wants_addon: bool = bool(party.get("dinner_addon", false))
	var mismatch := hint == "amber"
	var chunk_size: int = mini(int(room_stats["capacity"]), int(party["party_size"]))
	_admit_guest(party, room_type_id, instance_id, mismatch, chunk_size, wants_addon)

	var metric_key := "matched_mismatched" if mismatch else "matched_strict"
	_day_metrics[metric_key] += 1

	party["party_size"] -= chunk_size
	if party["party_size"] <= 0:
		pending_arrivals.remove_at(idx)
	return true


## The single Staffer<->Station reassignment path (ADR-0005): moves
## staffer_id into station_id, dropping it from wherever it was assigned
## before. If staffer_id had an in-flight Housekeeping or breakfast job and
## is actually moving to a different Station, that job is abandoned (see
## _cleaning_jobs'/_breakfast_jobs' doc comments) without touching any other
## Staffer's job. Returns false with no effect for an unknown Staffer or
## Station id.
func assign_staffer(staffer_id: String, station_id: String) -> bool:
	if not GameState.staffers.has(staffer_id) or not Station.is_valid(station_id):
		return false
	if GameState.staffer_station(staffer_id) != station_id:
		_cleaning_jobs.erase(staffer_id)
		_breakfast_jobs.erase(staffer_id)
		_dinner_jobs.erase(staffer_id)
	return GameState.reassign_staffer(staffer_id, station_id)


## Read-only lookup of a Housekeeping Staffer's in-flight job, for UI/tests.
## Returns {} if that Staffer isn't currently cleaning anything.
func cleaning_job(staffer_id: String) -> Dictionary:
	return _cleaning_jobs.get(staffer_id, {})


## Read-only lookup of a breakfast_queue entry by entry_id, for UI that needs
## a single entry's fields without walking the array itself. Returns {} if
## no such entry is currently queued.
func breakfast_entry(entry_id: int) -> Dictionary:
	var idx := _breakfast_index(entry_id)
	return breakfast_queue[idx] if idx != -1 else {}


## Read-only lookup of a Kitchen Staffer's in-flight breakfast job, for
## UI/tests. Returns {} if that Staffer isn't currently serving anyone.
func breakfast_job(staffer_id: String) -> Dictionary:
	return _breakfast_jobs.get(staffer_id, {})


## Read-only lookup of a walkin_queue entry by entry_id, for UI that needs a
## single entry's fields without walking the array itself. Returns {} if no
## such entry is currently queued.
func walkin_entry(entry_id: int) -> Dictionary:
	var idx := _walkin_index(entry_id)
	return walkin_queue[idx] if idx != -1 else {}


## Read-only lookup of a Kitchen Staffer's in-flight dinner job, for
## UI/tests. Returns {} if that Staffer isn't currently serving anyone.
func dinner_job(staffer_id: String) -> Dictionary:
	return _dinner_jobs.get(staffer_id, {})


func _on_phase_changed(day: int, phase_name: String) -> void:
	_midday_active = (phase_name == "MIDDAY")
	_evening_active = (phase_name == "EVENING")
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
	_tick_breakfast()
	_tick_dinner()
	if _evening_active:
		_decay_walkin_patience()
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

	_populate_breakfast_queue()

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
		"dining_served": 0,
		"dining_positive_reviews": 0,
		"dining_neutral_reviews": 0,
		"dining_negative_reviews": 0,
		"dining_walked_away": 0,
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

	_populate_walkin_queue()


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


## The Terrace's breakfast queue (ADR-0003): every currently-occupied Room's
## guest joins fresh each Morning, replacing whatever was left over from the
## day before -- an unserved guest doesn't carry into tomorrow's breakfast,
## same as the reference prototype. No build/unlock gate: the Terrace is a
## fixed structure present from Day 1, exactly like Reception.
func _populate_breakfast_queue() -> void:
	breakfast_queue.clear()
	_breakfast_jobs.clear()
	for room in GameState.hotel_rooms:
		if room["occupant"] == null:
			continue
		var guest: Dictionary = guests[room["occupant"]]
		breakfast_queue.append({
			"id": _next_breakfast_entry_id,
			"guest_id": guest["id"],
			"room_type_id": room["room_type_id"],
			"instance_id": int(room["instance_id"]),
			"species_id": guest["species_id"],
			"party_size": guest["party_size"],
		})
		_next_breakfast_entry_id += 1


## True while staffer_id is already mid-job on either Kitchen service --
## breakfast or dinner -- so the other tick loop's claim pass skips them.
## Skill alone doesn't decide which queue a dual-qualified Staffer (at/above
## both breakfast_min_skill and dinner_min_skill) ends up serving; whichever
## tick function runs first each frame (_tick_breakfast() before
## _tick_dinner(), see _on_tick_advanced()) gets first claim.
func _kitchen_busy(staffer_id: String) -> bool:
	return _breakfast_jobs.has(staffer_id) or _dinner_jobs.has(staffer_id)


## Parallel per-Staffer breakfast service (ADR-0005/0003), mirroring
## _tick_housekeeping()'s shape: every Kitchen Staffer not already mid-job
## and at/above stations.kitchen.breakfast_min_skill claims the next
## unclaimed queue entry and works it down over a Skill-dependent tick count
## (stations.kitchen.breakfast_ticks_by_skill). A Staffer below the
## threshold never claims a job at all, and an empty Kitchen Station simply
## never drains the queue -- same "no bailout deadline" behavior as an
## unstaffed Housekeeping Station leaving Rooms dirty indefinitely.
func _tick_breakfast() -> void:
	var min_skill: int = int(_station_balance("kitchen").get("breakfast_min_skill", 1))
	var ticks_by_skill: Dictionary = _station_balance("kitchen").get("breakfast_ticks_by_skill", {})
	var default_ticks: int = int(_station_balance("kitchen").get("default_breakfast_ticks", 20))

	for staffer_id in GameState.station_staffers("kitchen"):
		if _kitchen_busy(staffer_id):
			continue
		var skill: int = int(GameState.staffers[staffer_id]["skills"]["kitchen"])
		if skill < min_skill:
			continue
		var entry := _next_unclaimed_breakfast_entry()
		if entry.is_empty():
			continue
		var ticks: int = int(ticks_by_skill.get(str(skill), default_ticks))
		_breakfast_jobs[staffer_id] = {
			"entry_id": int(entry["id"]),
			"ticks_remaining": ticks,
		}

	for staffer_id in _breakfast_jobs.keys().duplicate():
		var job: Dictionary = _breakfast_jobs[staffer_id]
		job["ticks_remaining"] = int(job["ticks_remaining"]) - 1
		if job["ticks_remaining"] > 0:
			continue
		var idx := _breakfast_index(int(job["entry_id"]))
		if idx != -1:
			breakfast_queue.remove_at(idx)
		_breakfast_jobs.erase(staffer_id)


## The first breakfast_queue entry (queue order) no in-flight breakfast job
## is already targeting -- what a Kitchen Staffer who just freed up serves
## next. Returns {} if there's nothing left to claim.
func _next_unclaimed_breakfast_entry() -> Dictionary:
	var claimed: Dictionary = {}
	for job in _breakfast_jobs.values():
		claimed[int(job["entry_id"])] = true
	for entry in breakfast_queue:
		if not claimed.has(int(entry["id"])):
			return entry
	return {}


func _breakfast_index(entry_id: int) -> int:
	for i in range(breakfast_queue.size()):
		if int(breakfast_queue[i]["id"]) == entry_id:
			return i
	return -1


## The Terrace's Evening Walk-in Diner queue (ticket 10, ADR-0003): a fresh
## batch spawns the moment Evening starts (data/balance.json's
## dining.walkin_count_min/max), each with its own Patience -- unlike
## breakfast_queue's guest-per-occupied-Room source, these are new demand,
## Species-picked via DemandGenerator.pick_walkin_species() (biased toward
## GameState.daily_special, never Star-gated). Replaces whatever was left
## over from a prior Evening (there shouldn't be any -- _do_night() force-
## clears the queue when Evening ends). Also folds in every currently
## opted-in room guest's dinner add-on (ticket 12) -- see
## _queue_room_guest_addons().
func _populate_walkin_queue() -> void:
	walkin_queue.clear()
	_dinner_jobs.clear()
	var dining: Dictionary = GameState.balance.get("dining", {})
	# A purchased Terrace capacity upgrade (ticket 13, ADR-0003) widens both
	# ends of the Walk-in count range -- more tables means more Diners can
	# show up on any given Evening, not a guaranteed extra Diner every night.
	var capacity_delta: int = int(GameState.effective_terrace_stats()["capacity_delta"])
	var count_min: int = maxi(0, int(dining.get("walkin_count_min", 1)) + capacity_delta)
	var count_max: int = maxi(count_min, int(dining.get("walkin_count_max", 1)) + capacity_delta)
	var count: int = Rng.randi_range(count_min, count_max)
	var patience_start: float = float(dining.get("walkin_patience", {}).get("start", 0.0))

	for i in range(count):
		var species := DemandGenerator.pick_walkin_species(GameState.species, GameState.daily_special, dining, Rng)
		if species.is_empty():
			continue
		walkin_queue.append({
			"id": _next_walkin_id,
			"name": DemandGenerator.pick_name(species["id"], GameState.names, Rng),
			"species_id": species["id"],
			"party_size": Rng.randi_range(int(species["party_size"][0]), int(species["party_size"][1])),
			"patience": patience_start,
			"guest_id": -1,
		})
		_next_walkin_id += 1

	_queue_room_guest_addons(patience_start)


## Folds every currently-staying guest with an active dinner add-on (ticket
## 12, opted into at seat_party() time) into walkin_queue alongside this
## Evening's true Walk-in Diners -- same entry shape plus a guest_id back-
## reference so _resolve_room_guest_addon() can clear the opt-in once this
## Evening serves or loses it. A multi-night guest's add-on is a one-time
## choice made at check-in, not a nightly re-offer: once resolved (served or
## walked away), dinner_addon flips false on both the guest record and the
## Room card and this function no longer re-queues them on a later Evening.
func _queue_room_guest_addons(patience_start: float) -> void:
	for gid in guests.keys():
		var guest: Dictionary = guests[gid]
		if not guest.get("dinner_addon", false):
			continue
		walkin_queue.append({
			"id": _next_walkin_id,
			"name": guest["name"],
			"species_id": guest["species_id"],
			"party_size": int(guest["party_size"]),
			"patience": patience_start,
			"guest_id": gid,
		})
		_next_walkin_id += 1


## Parallel per-Staffer dinner service (ADR-0005/0003), mirroring
## _tick_breakfast()'s shape but gated on the higher
## stations.kitchen.dinner_min_skill: a Staffer who clears breakfast's bar
## fine may still sit below dinner's and simply never claim a Walk-in Diner.
## _kitchen_busy() keeps a Staffer already serving breakfast from also
## claiming a dinner job (and vice versa) -- one job at a time per Staffer,
## with breakfast's claim pass running first each tick (_on_tick_advanced()),
## so a dual-qualified Staffer with a leftover breakfast entry still pending
## finishes that before ever picking up a Walk-in Diner.
func _tick_dinner() -> void:
	var min_skill: int = int(_station_balance("kitchen").get("dinner_min_skill", 1))
	var ticks_by_skill: Dictionary = _station_balance("kitchen").get("dinner_ticks_by_skill", {})
	var default_ticks: int = int(_station_balance("kitchen").get("default_dinner_ticks", 20))

	for staffer_id in GameState.station_staffers("kitchen"):
		if _kitchen_busy(staffer_id):
			continue
		var skill: int = int(GameState.staffers[staffer_id]["skills"]["kitchen"])
		if skill < min_skill:
			continue
		var entry := _next_unclaimed_walkin_entry()
		if entry.is_empty():
			continue
		var ticks: int = int(ticks_by_skill.get(str(skill), default_ticks))
		_dinner_jobs[staffer_id] = {
			"entry_id": int(entry["id"]),
			"ticks_remaining": ticks,
		}

	for staffer_id in _dinner_jobs.keys().duplicate():
		var job: Dictionary = _dinner_jobs[staffer_id]
		job["ticks_remaining"] = int(job["ticks_remaining"]) - 1
		if job["ticks_remaining"] > 0:
			continue
		var idx := _walkin_index(int(job["entry_id"]))
		if idx != -1:
			_serve_walkin_diner(walkin_queue[idx], staffer_id)
			walkin_queue.remove_at(idx)
		_dinner_jobs.erase(staffer_id)


## The first walkin_queue entry (queue order) no in-flight dinner job is
## already targeting -- what a Kitchen Staffer who just freed up serves
## next. Returns {} if there's nothing left to claim.
func _next_unclaimed_walkin_entry() -> Dictionary:
	var claimed: Dictionary = {}
	for job in _dinner_jobs.values():
		claimed[int(job["entry_id"])] = true
	for entry in walkin_queue:
		if not claimed.has(int(entry["id"])):
			return entry
	return {}


func _walkin_index(entry_id: int) -> int:
	for i in range(walkin_queue.size()):
		if int(walkin_queue[i]["id"]) == entry_id:
			return i
	return -1


## A served Walk-in Diner's Reputation/Hearts outcome (ticket 11, ADR-0003):
## scored through Satisfaction.compute_dining() -- Daily Special match plus
## the serving Staffer's Kitchen skill -- then fed through the exact same
## review_for()/hearts_for()/reputation_delta_for_review() a Checkout's
## Satisfaction score goes through, so a good dining review moves Hearts/
## Reputation exactly like a good stay does. Takes the queue entry (not just
## its id) since the caller still holds it right before removing it from
## walkin_queue.
func _serve_walkin_diner(entry: Dictionary, staffer_id: String) -> void:
	var skill: int = int(GameState.staffers[staffer_id]["skills"]["kitchen"])
	var matches_special: bool = GameState.daily_special != "" and entry["species_id"] == GameState.daily_special
	var terrace_bonus: float = float(GameState.effective_terrace_stats()["satisfaction_bonus"])
	var sat := Satisfaction.compute_dining(matches_special, skill, GameState.balance, terrace_bonus)

	GameState.hearts += Satisfaction.hearts_for(sat, GameState.balance)
	var review := Satisfaction.review_for(sat, GameState.balance)
	GameState.reputation = clampi(GameState.reputation + Satisfaction.reputation_delta_for_review(review, GameState.balance), 0, 100)

	_day_metrics["dining_served"] += 1
	match review:
		"positive":
			_day_metrics["dining_positive_reviews"] += 1
		"negative":
			_day_metrics["dining_negative_reviews"] += 1
		_:
			_day_metrics["dining_neutral_reviews"] += 1

	_resolve_room_guest_addon(entry)
	EventBus.dining_guest_served.emit(entry["name"], entry["species_id"], review, sat)


## Clears a resolved room guest's dinner add-on opt-in (ticket 12) on both
## the guest record and its Room card, whether this Evening served it
## (_serve_walkin_diner()) or lost it to Patience expiry
## (_decay_walkin_patience()) -- either way the one-time add-on is spent and
## shouldn't be re-offered on a later Evening. A no-op for a true Walk-in
## Diner entry (guest_id -1, or a guest who has since checked out).
func _resolve_room_guest_addon(entry: Dictionary) -> void:
	var gid: int = int(entry.get("guest_id", -1))
	if gid == -1 or not guests.has(gid):
		return
	_set_dinner_addon(gid, false)


## The single place that keeps a guest's dinner_addon opt-in (ticket 12) in
## sync between its two mirrors -- the guest record (guests[gid]) and its
## Room's card-facing copy (occupant_dinner_addon) -- so a future third
## mutation site can't update one and forget the other.
func _set_dinner_addon(gid: int, value: bool) -> void:
	var guest: Dictionary = guests[gid]
	guest["dinner_addon"] = value
	var room := GameState.room_instance(guest["room_type_id"], guest["room_instance_id"])
	if not room.is_empty():
		room["occupant_dinner_addon"] = value


## Walk-in Diners' own Patience timer (ticket 10), independent of
## pending_arrivals' -- decays only while Evening is active (see
## _on_tick_advanced()) and freezes for an entry currently being served,
## mirroring _decay_patience()'s shape, including an unstaffed Kitchen
## burning Patience faster (CONTEXT.md's Patience entry: "decays over
## time -- faster if the relevant Station is unstaffed"), same as an
## unstaffed Reception. An entry whose Patience hits zero walks away
## immediately, same as an expired Room-booking Party.
func _decay_walkin_patience() -> void:
	var patience_cfg: Dictionary = GameState.balance.get("dining", {}).get("walkin_patience", {})
	var decay: float = float(patience_cfg.get("decay_per_tick", 0.0))
	if not GameState.is_station_staffed("kitchen"):
		decay *= float(patience_cfg.get("unstaffed_multiplier", 1.0))
	var being_served: Dictionary = {}
	for job in _dinner_jobs.values():
		being_served[int(job["entry_id"])] = true

	for entry in walkin_queue:
		if being_served.has(int(entry["id"])):
			continue
		entry["patience"] = maxf(0.0, float(entry["patience"]) - decay)

	var expired: Array = walkin_queue.filter(func(e): return not being_served.has(int(e["id"])) and float(e["patience"]) <= 0.0)
	for entry in expired:
		walkin_queue.erase(entry)
		# Same service failure as a lost Room-booking Party's Patience-expiry
		# walk-away (ticket 11, ADR-0003) -- an unserved Walk-in Diner is
		# never a "fully booked"/"too expensive" turn-away, so it always
		# stings Reputation, unconditionally.
		GameState.reputation = clampi(GameState.reputation + int(GameState.balance["review"]["reputation_delta_walkaway"]), 0, 100)
		_day_metrics["dining_walked_away"] += 1
		_resolve_room_guest_addon(entry)
		EventBus.dining_guest_walked_away.emit(entry["name"], entry["species_id"])


func _do_night(day: int) -> void:
	# The Terrace's dinner service closes for the night along with Evening
	# ending -- any Walk-in Diner still unserved (whether waiting or
	# mid-job) leaves rather than carrying over, same "no bailout" framing
	# as pending_arrivals' Evening-boundary force-expiry in _do_evening().
	walkin_queue.clear()
	_dinner_jobs.clear()

	var upkeep := 0
	for room in GameState.hotel_rooms:
		upkeep += int(GameState.effective_room_stats(room)["upkeep_per_day"])
	upkeep += int(GameState.effective_terrace_stats()["upkeep_per_day"])
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


func _admit_guest(party: Dictionary, room_type_id: String, instance_id: int, mismatch: bool, chunk_size: int, dinner_addon: bool = false) -> void:
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
		"dinner_addon": false,
	}
	room["occupant"] = gid
	room["occupant_name"] = party["name"]
	room["occupant_species_id"] = party["species_id"]
	room["occupant_mismatch"] = mismatch
	_set_dinner_addon(gid, dinner_addon)
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
	room["occupant_dinner_addon"] = false
	room["needs_cleaning"] = true
	guests.erase(gid)
	_day_metrics["checkouts"] += 1
	EventBus.room_marked_dirty.emit(g["room_type_id"], g["room_instance_id"])
