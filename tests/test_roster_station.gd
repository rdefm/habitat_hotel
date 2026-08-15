extends "res://tests/helpers/sim_test_base.gd"

## Characterizes the Roster & Station core (ADR-0002/0005): the three
## authored Staffers (Biscuit, Marlon, Shelly) each carry a Skill (1-5) at
## every Station, Sim.assign_staffer() is the sole reassignment path and
## interrupts only the moved Staffer's own in-flight Housekeeping job, and
## leaving a Station empty measurably degrades that Station's service
## (Reception's Patience decay, Bellhop's check-in delay, Housekeeping's
## cleaning throughput). Kitchen assignment is tracked but ungated until
## ticket 09 wires it to Dining. See
## .scratch/direct-manipulation-core-loop/issues/07-roster-station-core.md.
##
## Starting hotel (data/starting_hotel.json): cozy_nook#0 (capacity 2, tags
## warm/dry/quiet), roost_loft#0 (capacity 4, tags high_perch/dry),
## lagoon_room#0/#1 (capacity 3, tags warm/water). Default Station coverage
## (GameState.DEFAULT_STATION_ASSIGNMENTS): Biscuit/Reception,
## Marlon/Bellhop, Shelly/Housekeeping, Kitchen empty.

const START_PATIENCE: float = 80.0 # data/balance.json's patience.start
const DECAY_PER_TICK: float = 1.0 # data/balance.json's patience.decay_per_tick
const MIDDAY_START_TICK := 61 # Clock.PHASE_START_TICKS' MIDDAY entry
const RECEPTION_UNSTAFFED_MULTIPLIER := 1.6 # balance.json's stations.reception
const BELLHOP_UNSTAFFED_DELAY_TICKS := 16 # balance.json's stations.bellhop
const SHELLY_CLEAN_TICKS := 16 # balance.json's stations.housekeeping, skill 5


func _inject_party(id: int, needs: Array, party_size: int, budget: String = "low") -> void:
	Sim.pending_arrivals.append(make_party(id, needs, party_size, budget))


func _party_by_id(id: int) -> Dictionary:
	for p in Sim.pending_arrivals:
		if int(p["id"]) == id:
			return p
	return {}


## --- The three authored Staffers ---

func test_all_three_staffers_carry_a_skill_rating_at_every_station() -> void:
	assert_eq(GameState.staffers.keys().size(), 3)
	for id in ["biscuit", "marlon", "shelly"]:
		assert_true(GameState.staffers.has(id))
		var skills: Dictionary = GameState.staffers[id]["skills"]
		for station_id in ["reception", "bellhop", "housekeeping", "kitchen"]:
			assert_true(skills.has(station_id), "%s should have a %s skill" % [id, station_id])
			assert_between(int(skills[station_id]), 1, 5)


## --- Assignment/reassignment ---

func test_default_coverage_matches_the_reference_starting_assignment() -> void:
	assert_eq(GameState.staffer_station("biscuit"), "reception")
	assert_eq(GameState.staffer_station("marlon"), "bellhop")
	assert_eq(GameState.staffer_station("shelly"), "housekeeping")
	assert_true(GameState.station_staffers("kitchen").is_empty())


func test_assign_staffer_moves_a_staffer_to_any_station_at_any_time() -> void:
	var moved := Sim.assign_staffer("shelly", "reception")

	assert_true(moved)
	assert_eq(GameState.staffer_station("shelly"), "reception")
	assert_false(GameState.station_staffers("housekeeping").has("shelly"))
	assert_true(GameState.station_staffers("reception").has("biscuit"), "reassigning Shelly shouldn't bump Biscuit")


func test_assign_staffer_returns_false_and_has_no_effect_for_an_unknown_staffer_or_station() -> void:
	assert_false(Sim.assign_staffer("nobody", "reception"))
	assert_false(Sim.assign_staffer("biscuit", "not_a_station"))
	assert_eq(GameState.staffer_station("biscuit"), "reception", "a rejected reassignment shouldn't move anyone")


func test_kitchen_station_assignment_is_tracked_even_without_a_gated_effect_yet() -> void:
	assert_true(Sim.assign_staffer("marlon", "kitchen"))
	assert_eq(GameState.staffer_station("marlon"), "kitchen")
	assert_true(GameState.station_staffers("kitchen").has("marlon"))


## --- Reassigning mid-task interrupts only that Staffer's own job ---

func test_reassigning_a_housekeeper_mid_job_reverts_only_their_room_leaving_others_untouched() -> void:
	Sim.assign_staffer("marlon", "housekeeping") # Shelly + Marlon both cleaning now
	GameState.room_instance("cozy_nook", 0)["needs_cleaning"] = true
	GameState.room_instance("roost_loft", 0)["needs_cleaning"] = true

	Clock.force_advance_ticks(1) # both Staffers claim a Room and tick down once

	var shelly_job := Sim.cleaning_job("shelly")
	var marlon_job := Sim.cleaning_job("marlon")
	assert_false(shelly_job.is_empty())
	assert_false(marlon_job.is_empty())
	var marlon_ticks_before: int = int(marlon_job["ticks_remaining"])

	Sim.assign_staffer("shelly", "reception") # interrupt only Shelly's job

	assert_true(Sim.cleaning_job("shelly").is_empty(), "Shelly's in-flight job should be dropped")
	var marlon_job_after := Sim.cleaning_job("marlon")
	assert_eq(int(marlon_job_after["ticks_remaining"]), marlon_ticks_before, "Marlon's own progress shouldn't be touched")
	assert_true(GameState.room_instance(shelly_job["room_type_id"], int(shelly_job["instance_id"]))["needs_cleaning"], "Shelly's half-cleaned Room reverts to (stays) dirty")
	assert_true(GameState.room_instance(marlon_job["room_type_id"], int(marlon_job["instance_id"]))["needs_cleaning"], "Marlon's Room is still mid-clean, untouched by Shelly's reassignment")


## --- Leaving a Station empty visibly degrades its service ---

func test_empty_reception_station_measurably_increases_patience_decay() -> void:
	Clock.force_advance_ticks(1) # Day 1's Morning
	_inject_party(999, ["warm", "dry", "quiet"], 1)
	Clock.force_advance_ticks(MIDDAY_START_TICK - 1) # lands on the tick that flips the phase to MIDDAY

	Clock.force_advance_ticks(1) # first tick fully inside Midday, Reception staffed
	assert_eq(_party_by_id(999)["patience"], START_PATIENCE - DECAY_PER_TICK)

	Sim.assign_staffer("biscuit", "kitchen") # empty Reception
	Clock.force_advance_ticks(1)
	assert_eq(_party_by_id(999)["patience"], START_PATIENCE - DECAY_PER_TICK - DECAY_PER_TICK * RECEPTION_UNSTAFFED_MULTIPLIER)


## ADR-0014/0017 inverted this: a staffed Bellhop now Escorts (a Skill-scaled
## per-Staffer Job, see test_bellhop_escort.gd) rather than seating instantly,
## while the unstaffed case's flat delay is unchanged.
func test_empty_bellhop_station_measurably_slows_check_in_versus_staffed() -> void:
	_inject_party(1, ["warm", "water"], 1)
	Sim.seat_party(1, "lagoon_room", 0) # Bellhop staffed (Marlon) -- an Escort, not instant
	var staffed_room := GameState.room_instance("lagoon_room", 0)
	assert_true(staffed_room["checking_in"], "a staffed Bellhop should still Escort, not seat instantly")

	Sim.assign_staffer("marlon", "kitchen") # empty Bellhop
	_inject_party(2, ["warm", "water"], 1)
	Sim.seat_party(2, "lagoon_room", 1)
	var unstaffed_room := GameState.room_instance("lagoon_room", 1)
	assert_true(unstaffed_room["checking_in"], "an unstaffed Bellhop should delay check-in")
	assert_eq(int(unstaffed_room["checkin_ticks_remaining"]), BELLHOP_UNSTAFFED_DELAY_TICKS)

	Clock.force_advance_ticks(BELLHOP_UNSTAFFED_DELAY_TICKS)
	assert_false(GameState.room_instance("lagoon_room", 1)["checking_in"], "the delay should resolve on its own")


func test_empty_housekeeping_station_leaves_rooms_dirty_longer_than_staffed() -> void:
	GameState.room_instance("cozy_nook", 0)["needs_cleaning"] = true
	Clock.force_advance_ticks(SHELLY_CLEAN_TICKS) # Shelly (skill 5) is staffed by default
	assert_false(GameState.room_instance("cozy_nook", 0)["needs_cleaning"], "a staffed Housekeeping should have finished by now")

	Sim.assign_staffer("shelly", "kitchen") # empty Housekeeping
	GameState.room_instance("roost_loft", 0)["needs_cleaning"] = true
	Clock.force_advance_ticks(SHELLY_CLEAN_TICKS)
	assert_true(GameState.room_instance("roost_loft", 0)["needs_cleaning"], "an unstaffed Housekeeping Station should never pick this Room up")
