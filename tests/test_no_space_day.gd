class_name TestNoSpaceDay
extends RefCounted

const TestHelpers = preload("res://tests/test_helpers.gd")
const BotPolicy = preload("res://tests/bot_policy.gd")

## Part F test 7: more arrivals than capacity => excess parties wait out
## their patience and walk (Part E: "no special case" for a party that
## can't fit anywhere), sim never errors, day completes.

static func run() -> Array[String]:
	var failures: Array[String] = []
	var sim := TestHelpers.new_sim(1)
	var state := sim.get_state()
	var dt := TestHelpers.tick_dt(sim)

	var room_count: int = state.rooms.size()
	var arrivals_n := room_count + 2  # deliberately more parties than rooms

	state.queue.clear()
	var short_patience := dt * 2.0
	for i in range(arrivals_n):
		var party_id := state.next_party_id
		state.next_party_id += 1
		state.queue.append({
			"party_id": party_id, "species_id": "pigeon", "party_count": 1, "original_party_count": 1,
			"nights_total": 1, "patience_remaining": short_patience, "patience_max": short_patience,
			"rooms_used": 0, "arrival_day": state.day,
		})

	var guard := 0
	while not state.queue.is_empty() and guard < 2_000_000:
		guard += 1
		BotPolicy.act(sim)
		sim.advance(dt)

	TestHelpers.assert_true(state.queue.is_empty(), "NoSpaceDay: the day should complete cleanly, queue eventually empty (seated or walked)", failures)
	TestHelpers.assert_eq(state.stays.size(), room_count, "NoSpaceDay: exactly the room count should have been seated", failures)

	var walked_count := 0
	for log in state.turned_away_log:
		TestHelpers.assert_eq(log["reason"], "impatient", "NoSpaceDay: excess parties are logged as turned away with reason 'impatient'", failures)
		walked_count += 1
	TestHelpers.assert_eq(walked_count, arrivals_n - room_count, "NoSpaceDay: exactly the excess parties should have walked", failures)
	TestHelpers.assert_true(not is_nan(float(state.cash)), "NoSpaceDay: cash must never become NaN", failures)

	return failures
