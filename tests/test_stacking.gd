extends "res://tests/helpers/sim_test_base.gd"

## Characterizes Stacking (ADR-0008, ticket 09): dragging a second Staffer
## onto a Room already mid-clean (a Housekeeping Job) or a Terrace
## breakfast/dinner queue entry already being served (a Kitchen Job) stacks
## them onto that same Job -- summing their per-Station Skill (capped at 5,
## the existing scale's max) and looking up the combined ticks in the same
## data/balance.json per-skill tables _tick_housekeeping()/_tick_breakfast()/
## _tick_dinner() already use for a single Staffer, just keyed by the summed
## value instead -- no second formula. Up to 2 Staffers per Job; a third
## drop is rejected with no state change. See
## .scratch/direct-manipulation-amendments/issues/09-drag-drop-stacking.md.
##
## Starting hotel (data/starting_hotel.json): cozy_nook#0, roost_loft#0.
## Default Station coverage: Biscuit/Reception, Marlon/Bellhop,
## Shelly/Housekeeping, Kitchen empty. Skills (data/staffers.json):
## Biscuit R5 B2 H2 K1, Marlon R2 B5 H3 K3, Shelly R1 B1 H5 K2.

const HK_TICKS_BY_SKILL: Dictionary = {"1": 40, "2": 32, "3": 26, "4": 20, "5": 16} # balance.json
const BREAKFAST_TICKS_BY_SKILL: Dictionary = {"1": 24, "2": 20, "3": 16, "4": 14, "5": 12}
const DINNER_TICKS_BY_SKILL: Dictionary = {"1": 36, "2": 28, "3": 22, "4": 18, "5": 14}


func _seat(party_id: int, room_type_id: String, instance_id: int, needs: Array) -> void:
	Sim.pending_arrivals.append(make_party(party_id, needs, 1))
	Sim.seat_party(party_id, room_type_id, instance_id)


func _push_walkin(id: int, patience: float, species_id: String = "test_species") -> void:
	Sim.walkin_queue.append({
		"id": id,
		"name": "Test Diner %d" % id,
		"species_id": species_id,
		"party_size": 1,
		"patience": patience,
	})


## --- Housekeeping stacking ---

func test_stacking_onto_a_room_with_no_in_flight_job_is_rejected() -> void:
	GameState.room_instance("roost_loft", 0)["needs_cleaning"] = true # dirty, but Shelly is Housekeeping's only Staffer and isn't targeting it

	assert_false(Sim.can_stack_staffer_on_room("marlon", "roost_loft", 0))
	assert_false(Sim.stack_staffer_on_room("marlon", "roost_loft", 0))
	assert_eq(GameState.staffer_station("marlon"), "bellhop", "a rejected stack shouldn't move the Staffer's Station")
	assert_true(Sim.cleaning_job("marlon").is_empty())


func test_stacking_onto_an_in_progress_room_sums_skill_and_looks_up_combined_ticks() -> void:
	GameState.room_instance("cozy_nook", 0)["needs_cleaning"] = true
	Clock.force_advance_ticks(1) # Shelly (default Housekeeping, skill 5) claims cozy_nook

	assert_true(Sim.can_stack_staffer_on_room("marlon", "cozy_nook", 0))
	var stacked := Sim.stack_staffer_on_room("marlon", "cozy_nook", 0)

	assert_true(stacked)
	assert_eq(GameState.staffer_station("marlon"), "housekeeping", "stacking pulls the dragged Staffer onto the Station too")
	var expected: int = HK_TICKS_BY_SKILL[str(mini(5 + 3, 5))] # Shelly 5 + Marlon 3, capped at 5
	assert_eq(int(Sim.cleaning_job("marlon")["ticks_remaining"]), expected)
	assert_eq(int(Sim.cleaning_job("shelly")["ticks_remaining"]), expected)
	assert_eq(Sim.cleaning_job("marlon")["room_type_id"], "cozy_nook")


func test_stacking_sums_skill_rather_than_taking_the_max_when_under_the_cap() -> void:
	GameState.staffers["shelly"]["skills"]["housekeeping"] = 1
	GameState.staffers["marlon"]["skills"]["housekeeping"] = 2
	GameState.room_instance("cozy_nook", 0)["needs_cleaning"] = true
	Clock.force_advance_ticks(1) # Shelly claims cozy_nook at (edited) skill 1

	Sim.stack_staffer_on_room("marlon", "cozy_nook", 0)

	var expected: int = HK_TICKS_BY_SKILL[str(1 + 2)] # well under the cap of 5
	assert_eq(int(Sim.cleaning_job("marlon")["ticks_remaining"]), expected)
	assert_eq(int(Sim.cleaning_job("shelly")["ticks_remaining"]), expected)


func test_a_third_staffer_dropped_onto_a_full_housekeeping_job_is_rejected() -> void:
	GameState.room_instance("cozy_nook", 0)["needs_cleaning"] = true
	Clock.force_advance_ticks(1) # Shelly claims cozy_nook
	Sim.stack_staffer_on_room("marlon", "cozy_nook", 0) # now 2 Staffers deep
	var marlon_ticks_before: int = int(Sim.cleaning_job("marlon")["ticks_remaining"])
	var shelly_ticks_before: int = int(Sim.cleaning_job("shelly")["ticks_remaining"])

	assert_false(Sim.can_stack_staffer_on_room("biscuit", "cozy_nook", 0))
	var rejected := Sim.stack_staffer_on_room("biscuit", "cozy_nook", 0)

	assert_false(rejected)
	assert_eq(GameState.staffer_station("biscuit"), "reception", "a rejected stack shouldn't move the Staffer's Station")
	assert_true(Sim.cleaning_job("biscuit").is_empty())
	assert_eq(Sim.cleaning_staffers("cozy_nook", 0).size(), 2, "no state change on a rejected third drop")
	assert_eq(int(Sim.cleaning_job("marlon")["ticks_remaining"]), marlon_ticks_before)
	assert_eq(int(Sim.cleaning_job("shelly")["ticks_remaining"]), shelly_ticks_before)


func test_stacking_onto_a_different_room_abandons_the_staffers_own_job() -> void:
	Sim.assign_staffer("marlon", "housekeeping")
	GameState.room_instance("cozy_nook", 0)["needs_cleaning"] = true
	GameState.room_instance("roost_loft", 0)["needs_cleaning"] = true
	Clock.force_advance_ticks(1) # Shelly and Marlon each claim a different Room

	var marlon_job_before := Sim.cleaning_job("marlon")
	assert_eq(marlon_job_before["room_type_id"], "roost_loft")

	Sim.stack_staffer_on_room("marlon", "cozy_nook", 0) # drag Marlon onto Shelly's Room instead

	assert_eq(Sim.cleaning_job("marlon")["room_type_id"], "cozy_nook")
	assert_true(GameState.room_instance("roost_loft", 0)["needs_cleaning"], "Marlon's abandoned Room stays dirty")
	assert_true(Sim.cleaning_staffers("roost_loft", 0).is_empty(), "nobody targets the abandoned Room anymore")


## --- Kitchen stacking (breakfast) ---

func test_stacking_onto_an_in_progress_breakfast_entry_sums_skill_and_looks_up_combined_ticks() -> void:
	Sim.assign_staffer("shelly", "kitchen") # skill 2, at breakfast_min_skill
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	Clock.force_advance_ticks(1) # Day 1's Morning: Shelly claims the breakfast entry
	var entry_id: int = int(Sim.breakfast_job("shelly")["entry_id"])

	assert_true(Sim.can_stack_staffer_on_breakfast("marlon", entry_id))
	var stacked := Sim.stack_staffer_on_breakfast("marlon", entry_id)

	assert_true(stacked)
	assert_eq(GameState.staffer_station("marlon"), "kitchen")
	var expected: int = BREAKFAST_TICKS_BY_SKILL[str(mini(2 + 3, 5))]
	assert_eq(int(Sim.breakfast_job("marlon")["ticks_remaining"]), expected)
	assert_eq(int(Sim.breakfast_job("shelly")["ticks_remaining"]), expected)
	assert_eq(int(Sim.breakfast_job("marlon")["entry_id"]), entry_id)


func test_stacking_onto_a_breakfast_entry_with_no_in_flight_job_is_rejected() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	Clock.force_advance_ticks(1) # Day 1's Morning populates the queue; Kitchen is unstaffed, nobody claims it
	var entry_id: int = int(Sim.breakfast_queue[0]["id"])

	assert_false(Sim.can_stack_staffer_on_breakfast("marlon", entry_id))
	assert_false(Sim.stack_staffer_on_breakfast("marlon", entry_id))


func test_a_third_staffer_dropped_onto_a_full_breakfast_job_is_rejected() -> void:
	Sim.assign_staffer("shelly", "kitchen")
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	Clock.force_advance_ticks(1)
	var entry_id: int = int(Sim.breakfast_job("shelly")["entry_id"])
	Sim.stack_staffer_on_breakfast("marlon", entry_id)

	assert_false(Sim.can_stack_staffer_on_breakfast("biscuit", entry_id))
	var rejected := Sim.stack_staffer_on_breakfast("biscuit", entry_id)

	assert_false(rejected)
	assert_true(Sim.breakfast_job("biscuit").is_empty())
	assert_eq(Sim.breakfast_staffers(entry_id).size(), 2)


## --- Kitchen stacking (dinner / Walk-in) ---

func test_stacking_onto_an_in_progress_dinner_entry_sums_skill_and_looks_up_combined_ticks() -> void:
	Sim.assign_staffer("marlon", "kitchen") # skill 3, at dinner_min_skill
	_push_walkin(1, 999.0)
	Clock.force_advance_ticks(1) # Marlon claims the Walk-in Diner
	var entry_id: int = int(Sim.dinner_job("marlon")["entry_id"])

	assert_true(Sim.can_stack_staffer_on_dinner("shelly", entry_id))
	var stacked := Sim.stack_staffer_on_dinner("shelly", entry_id)

	assert_true(stacked)
	assert_eq(GameState.staffer_station("shelly"), "kitchen")
	var expected: int = DINNER_TICKS_BY_SKILL[str(mini(3 + 2, 5))]
	assert_eq(int(Sim.dinner_job("shelly")["ticks_remaining"]), expected)
	assert_eq(int(Sim.dinner_job("marlon")["ticks_remaining"]), expected)


func test_a_third_staffer_dropped_onto_a_full_dinner_job_is_rejected() -> void:
	Sim.assign_staffer("marlon", "kitchen")
	_push_walkin(1, 999.0)
	Clock.force_advance_ticks(1)
	var entry_id: int = int(Sim.dinner_job("marlon")["entry_id"])
	Sim.stack_staffer_on_dinner("shelly", entry_id)

	assert_false(Sim.can_stack_staffer_on_dinner("biscuit", entry_id))
	var rejected := Sim.stack_staffer_on_dinner("biscuit", entry_id)

	assert_false(rejected)
	assert_true(Sim.dinner_job("biscuit").is_empty())
	assert_eq(Sim.dinner_staffers(entry_id).size(), 2)
