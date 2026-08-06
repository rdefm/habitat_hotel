extends "res://tests/helpers/sim_test_base.gd"

## Characterizes the batch runner's scripted seating autopilot (see
## .scratch/direct-manipulation-core-loop/issues/06-batch-runner-autopilot.md):
## every arrival is seated through Sim.seat_party() -- the same single
## admission path interactive play uses, never a second implementation --
## picking the smallest-capacity green Room, falling back to the
## smallest-capacity amber Room, and leaving the Party queued to expire on
## its own Patience if neither exists.
##
## Starting hotel (data/starting_hotel.json): cozy_nook#0 (capacity 2, tags
## warm/dry/quiet), roost_loft#0 (capacity 4, tags high_perch/dry),
## lagoon_room#0/#1 (capacity 3, tags warm/water).

const BatchRunner = preload("res://sim/batch_runner.gd")


func test_picks_the_smallest_capacity_green_room_over_a_smaller_capacity_amber_room() -> void:
	Clock.force_advance_ticks(1)
	# roost_loft (cap 4) is a full match; cozy_nook (cap 2) is smaller but only amber.
	Sim.pending_arrivals.append(make_party(1, ["high_perch", "dry"], 1, "low"))

	watch_signals(EventBus)
	BatchRunner._seat_pending_arrivals()

	var room := GameState.room_instance("roost_loft", 0)
	assert_eq(room["occupant_name"], "Test Guest 1", "green should win even though an amber Room is smaller")
	assert_false(room["occupant_mismatch"])
	assert_true(Sim.pending_party(1).is_empty())
	assert_signal_emitted_with_parameters(EventBus, "guest_seated", ["Test Guest 1", "test_species", "roost_loft", 0, false])


func test_picks_the_smallest_capacity_green_room_among_several_green_rooms() -> void:
	Clock.force_advance_ticks(1)
	Sim.pending_arrivals.append(make_party(1, [], 1, "low")) # no Needs -- every built Room is green

	BatchRunner._seat_pending_arrivals()

	var room := GameState.room_instance("cozy_nook", 0) # capacity 2, smallest of the four
	assert_eq(room["occupant_name"], "Test Guest 1")
	assert_false(room["occupant_mismatch"])


func test_falls_back_to_the_smallest_capacity_amber_room_when_no_green_room_exists() -> void:
	Clock.force_advance_ticks(1)
	Sim.pending_arrivals.append(make_party(1, ["cold"], 1, "low")) # no built Room has this tag -- every Room is amber

	BatchRunner._seat_pending_arrivals()

	var room := GameState.room_instance("cozy_nook", 0) # capacity 2, smallest of the four
	assert_eq(room["occupant_name"], "Test Guest 1")
	assert_true(room["occupant_mismatch"])


func test_leaves_the_party_queued_to_expire_on_its_own_patience_when_neither_hint_is_available() -> void:
	Clock.force_advance_ticks(1)
	Sim.pending_arrivals.append(make_party(1, ["warm", "dry", "quiet"], 1, "low"))
	for room in GameState.hotel_rooms: # nowhere to seat this party
		room["occupant"] = -1

	BatchRunner._seat_pending_arrivals()

	var party := Sim.pending_party(1)
	assert_false(party.is_empty(), "the party should still be queued, not discarded")
	assert_eq(party["party_size"], 1)
	assert_eq(Sim.guests.size(), 0)


func test_an_oversized_party_is_seated_chunk_by_chunk_across_rooms_by_a_single_pass() -> void:
	Clock.force_advance_ticks(1)
	GameState.build_room("lagoon_room") # lagoon_room#2, so 3x capacity-3 lagoon rooms exist
	Sim.pending_arrivals.append(make_party(1, ["warm", "water"], 9, "low")) # 3 lagoon rooms x capacity 3 = 9

	BatchRunner._seat_pending_arrivals()

	assert_true(Sim.pending_party(1).is_empty(), "the whole party should be seated across the three lagoon rooms")
	assert_eq(Sim.guests.size(), 3)


func test_run_wires_the_autopilot_into_the_real_day_cycle_without_a_policy_argument() -> void:
	var rows := BatchRunner.run(1, "user://test_batch_runner_autopilot.csv")

	assert_eq(rows.size(), 1)
	assert_gt(rows[0]["matched_strict"] + rows[0]["matched_mismatched"], 0, "Day 1's arrivals should have been auto-seated")
