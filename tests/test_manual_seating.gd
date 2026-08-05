extends "res://tests/helpers/sim_test_base.gd"

## Characterizes the manual seating core (ADR-0001): arrivals sit in
## Sim.pending_arrivals as a queryable Party queue with per-entry Patience
## that decays tick-by-tick only during Midday (Clock.force_advance_ticks()
## lets these tests land mid-phase without waiting out a whole day),
## Sim.match_hint()/Sim.seat_party() are the sole green/amber/none-and-admit
## pair everything (interactive or scripted) goes through, and an oversized
## Party can be split across Rooms with its remainder's Patience left
## untouched. See
## .scratch/direct-manipulation-core-loop/issues/04-manual-seating-core.md.
##
## Starting hotel (data/starting_hotel.json): cozy_nook#0 (capacity 2, tags
## warm/dry/quiet), roost_loft#0 (capacity 4, tags high_perch/dry),
## lagoon_room#0/#1 (capacity 3, tags warm/water).

const START_PATIENCE: float = 80.0 # data/balance.json's patience.start
const DECAY_PER_TICK: float = 1.0 # data/balance.json's patience.decay_per_tick
const MIDDAY_START_TICK := 61 # Clock.PHASE_START_TICKS' MIDDAY entry


func _inject_party(id: int, needs: Array, party_size: int, budget: String = "low") -> void:
	Sim.pending_arrivals.append(make_party(id, needs, party_size, budget))


func _party_by_id(id: int) -> Dictionary:
	for p in Sim.pending_arrivals:
		if int(p["id"]) == id:
			return p
	return {}


## --- Queryable pending queue ---

func test_arrivals_are_queryable_as_a_pending_queue_after_morning() -> void:
	Clock.force_advance_ticks(1)

	assert_gt(Sim.pending_arrivals.size(), 0, "Day 1 should have generated at least one arrival")
	for party in Sim.pending_arrivals:
		assert_eq(party["patience"], START_PATIENCE, "Patience should start untouched before Midday begins")


## --- Patience decay/expiry ---

func test_patience_only_decays_once_midday_is_underway() -> void:
	Clock.force_advance_ticks(1) # Day 1's Morning
	_inject_party(999, ["warm", "dry", "quiet"], 1)

	Clock.force_advance_ticks(MIDDAY_START_TICK - 1) # lands on the tick that flips the phase to MIDDAY
	assert_eq(_party_by_id(999)["patience"], START_PATIENCE, "Patience shouldn't decay before Midday's first tick has fully elapsed")

	Clock.force_advance_ticks(1) # the first tick fully inside Midday
	assert_eq(_party_by_id(999)["patience"], START_PATIENCE - DECAY_PER_TICK)

	Clock.force_advance_ticks(5)
	assert_eq(_party_by_id(999)["patience"], START_PATIENCE - DECAY_PER_TICK * 6)


func test_a_partys_patience_expiring_removes_it_from_the_queue_and_walks_it_away() -> void:
	Clock.force_advance_ticks(1)
	_inject_party(999, ["warm", "dry", "quiet"], 1)
	for room in GameState.hotel_rooms: # nowhere to seat this party -> "fully_booked"
		room["occupant"] = -1

	watch_signals(EventBus)
	Clock.force_advance_ticks(MIDDAY_START_TICK + int(START_PATIENCE) + 1)

	assert_true(_party_by_id(999).is_empty(), "the expired party should be gone from the pending queue")
	assert_signal_emitted_with_parameters(EventBus, "guest_turned_away", ["Test Guest 999", "test_species", "fully_booked"])


func test_patience_expiring_with_no_eligible_room_type_costs_reputation() -> void:
	Clock.force_advance_ticks(1)
	_inject_party(999, ["nonexistent_tag"], 1) # no built room type ever has this tag
	var reputation_before: int = GameState.reputation

	Clock.force_advance_ticks(MIDDAY_START_TICK + int(START_PATIENCE) + 1)

	assert_eq(GameState.reputation, reputation_before + int(GameState.balance["review"]["reputation_delta_walkaway"]))


## --- Seat action (the one admission path) ---

func test_seat_party_seats_a_green_match_immediately() -> void:
	_inject_party(1, ["warm", "dry", "quiet"], 2, "low")

	watch_signals(EventBus)
	var seated := Sim.seat_party(1, "cozy_nook", 0)

	assert_true(seated)
	var room := GameState.room_instance("cozy_nook", 0)
	assert_eq(room["occupant_name"], "Test Guest 1")
	assert_false(room["occupant_mismatch"])
	assert_true(_party_by_id(1).is_empty(), "a party fully seated in one room should leave the queue")
	assert_signal_emitted_with_parameters(EventBus, "guest_seated", ["Test Guest 1", "test_species", "cozy_nook", 0, false])


func test_seat_party_applies_mismatch_handling_for_an_amber_match() -> void:
	_inject_party(1, ["cold", "water"], 2, "low") # needs cozy_nook's tags don't cover at all

	var seated := Sim.seat_party(1, "cozy_nook", 0)

	assert_true(seated)
	var room := GameState.room_instance("cozy_nook", 0)
	assert_true(room["occupant_mismatch"])
	assert_true(Sim.guests.values()[0]["mismatch"])


func test_seat_party_returns_false_and_has_no_effect_for_a_none_hint_room() -> void:
	_inject_party(1, ["warm", "dry", "quiet"], 2, "low")
	GameState.hotel_rooms[0]["occupant"] = -1 # occupy cozy_nook#0

	var seated := Sim.seat_party(1, "cozy_nook", 0)

	assert_false(seated)
	assert_eq(_party_by_id(1)["party_size"], 2, "an occupied room shouldn't respond to a seat attempt at all")
	assert_eq(Sim.guests.size(), 0)


func test_match_hint_reflects_classify_for_a_pending_party() -> void:
	_inject_party(1, ["warm", "dry", "quiet"], 2, "low")

	assert_eq(Sim.match_hint(1, "cozy_nook", 0), "green")


func test_match_hint_is_none_for_an_unknown_party_or_room() -> void:
	assert_eq(Sim.match_hint(999, "cozy_nook", 0), "none")
	_inject_party(1, ["warm", "dry", "quiet"], 2, "low")
	assert_eq(Sim.match_hint(1, "cozy_nook", 99), "none")


## --- Splitting an oversized Party across Rooms ---

func test_oversized_party_splits_across_rooms_leaving_remainder_queued_with_patience_unchanged() -> void:
	_inject_party(1, ["high_perch", "dry"], 6, "low") # roost_loft's capacity is 4

	var seated := Sim.seat_party(1, "roost_loft", 0)

	assert_true(seated)
	var remaining := _party_by_id(1)
	assert_false(remaining.is_empty(), "2 of the party's 6 members should still be queued")
	assert_eq(remaining["party_size"], 2)
	assert_eq(remaining["patience"], START_PATIENCE, "a partial seating shouldn't touch the remainder's Patience")
	assert_eq(Sim.guests.values()[0]["party_size"], 4)


func test_a_split_partys_remainder_can_be_fully_seated_by_a_second_seat_action() -> void:
	_inject_party(1, ["high_perch", "dry"], 6, "low")
	Sim.seat_party(1, "roost_loft", 0)
	GameState.build_room("roost_loft") # roost_loft#1

	var seated_again := Sim.seat_party(1, "roost_loft", 1)

	assert_true(seated_again)
	assert_true(_party_by_id(1).is_empty(), "the whole party should now be fully seated across two rooms")
	assert_eq(Sim.guests.size(), 2)
