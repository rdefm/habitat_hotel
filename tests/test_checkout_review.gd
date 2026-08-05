extends "res://tests/helpers/sim_test_base.gd"

## Characterizes a checkout producing a review once a guest has been admitted
## through the new manual seat_party() action (ADR-0001) rather than the
## deleted auto-matcher. The checkout/review/Hearts/Reputation machinery
## itself is untouched by this ticket, so these tests exercise it through
## the new admission path with a hand-built Party -- deterministic, with no
## dependency on DemandGenerator's RNG output -- rather than trying to
## reproduce specific Day-1 arrivals. See
## .scratch/direct-manipulation-core-loop/issues/04-manual-seating-core.md.
##
## Quirk worth knowing if these ever need re-deriving: force_advance_day()
## runs exactly one day's 240 ticks, and the tick that rolls day N into day
## N+1 immediately fires day N+1's Morning phase (checkout processing) in
## the same call, one call before that day's own day_summary is emitted. So
## an N-night guest's checkout/review is posted during the Nth call to
## force_advance_day() after they were seated, not the (N+1)th.

func test_a_green_seated_guests_stay_ends_in_a_positive_review_with_hearts_and_reputation() -> void:
	Clock.force_advance_ticks(1) # Day 1 Morning, so the queue/day machinery is live
	Sim.pending_arrivals.append(make_party(9001, ["warm", "dry", "quiet"], 1, "low", 5)) # full match for cozy_nook#0
	assert_true(Sim.seat_party(9001, "cozy_nook", 0))
	var reputation_before := GameState.reputation

	watch_signals(EventBus)
	for i in range(5): # a 5-night stay checks out during the 5th force_advance_day() call
		Clock.force_advance_day()

	assert_signal_emit_count(EventBus, "review_posted", 1)
	assert_signal_emit_count(EventBus, "guest_checked_out", 1)
	assert_signal_emit_count(EventBus, "room_marked_dirty", 1)
	assert_eq(GameState.review_history.size(), 1)

	var review: Dictionary = GameState.review_history[0]
	assert_eq(review["species_id"], "test_species")
	assert_eq(review["satisfaction"], 75.0, "base 60 + the 5-night care bonus capped at 15")
	assert_eq(review["review"], "positive")
	assert_eq(review["revenue"], 200, "cozy_nook's base_rate 40 * 5 nights at the default 1.0 price multiplier")
	assert_eq(GameState.hearts, 1)
	assert_eq(GameState.reputation, reputation_before + int(GameState.balance["review"]["reputation_delta_positive"]))


func test_an_amber_seated_guests_mismatch_penalty_can_produce_a_negative_review_and_cost_reputation() -> void:
	Clock.force_advance_ticks(1)
	Sim.pending_arrivals.append(make_party(9002, ["cold", "water"], 1, "low", 2)) # cozy_nook covers neither need
	assert_true(Sim.seat_party(9002, "cozy_nook", 0))
	assert_true(Sim.guests.values()[0]["mismatch"])
	var reputation_before := GameState.reputation

	for i in range(2):
		Clock.force_advance_day()

	assert_eq(GameState.review_history.size(), 1)
	var review: Dictionary = GameState.review_history[0]
	assert_eq(review["satisfaction"], 16.0, "base 60 - 2 missing-need penalties of 25 + the 2-night care bonus of 6")
	assert_eq(review["review"], "negative")
	assert_eq(GameState.hearts, 0)
	assert_eq(GameState.reputation, reputation_before + int(GameState.balance["review"]["reputation_delta_negative"]))


func test_checkout_leaves_its_room_dirty_and_vacant_until_the_next_evening_cleans_it() -> void:
	Clock.force_advance_ticks(1)
	Sim.pending_arrivals.append(make_party(9001, ["warm", "dry", "quiet"], 1, "low", 2))
	Sim.seat_party(9001, "cozy_nook", 0)

	Clock.force_advance_day()
	Clock.force_advance_day()

	var room := GameState.room_instance("cozy_nook", 0)
	assert_eq(room["occupant"], null, "checkout should have freed the room")
	assert_true(room["needs_cleaning"], "a freshly freed room starts dirty -- Evening hasn't cleaned it yet")

	watch_signals(EventBus)
	Clock.force_advance_day()

	assert_signal_emit_count(EventBus, "room_cleaned", 1)
	assert_false(GameState.room_instance("cozy_nook", 0)["needs_cleaning"])
