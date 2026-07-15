class_name TestQueueClearability
extends RefCounted

const TestHelpers = preload("res://tests/test_helpers.gd")
const BotPolicy = preload("res://tests/bot_policy.gd")

## Part F test 6: an attentive bot (always seats the best available option
## the moment it exists) clears a max-arrivals day with zero impatient
## walk-aways at 1x -- and, because patience is sim-time, the same test at
## 2x is definitionally identical (asserted anyway).
##
## Room capacity is deliberately made non-limiting here (extra rooms are
## built first) so this test isolates the sim-time-vs-real-time question;
## capacity-insufficiency is covered separately by test 7 (No-space day).

static func run() -> Array[String]:
	var failures: Array[String] = []
	_run_at_speed(1.0, failures)
	_run_at_speed(2.0, failures)
	return failures

static func _run_at_speed(speed: float, failures: Array[String]) -> void:
	var sim := TestHelpers.new_sim(1)
	var state := sim.get_state()
	var content := sim.get_content()
	var balance: Dictionary = content.balance
	var max_n := int(balance.get("arrivals_per_day_max", 5))

	state.cash = 1_000_000
	var built := 0
	for room in state.rooms:
		if room["state"] != "empty":
			built += 1
	while built < max_n:
		var plot_id := -1
		for room in state.rooms:
			if room["state"] == "empty":
				plot_id = int(room["plot_id"])
				break
		if plot_id == -1:
			break
		sim.submit({"type": "build_room", "plot_id": plot_id, "room_type": "cozy_nook"})
		built += 1
	sim.drain_events()

	state.queue.clear()
	var species: Dictionary = content.species["pigeon"]  # shortest patience_mult in the M1 roster
	var patience_max: float = float(balance.get("base_patience_sim_seconds", 35.0)) * float(species.get("patience_mult", 1.0))
	for i in range(max_n):
		var party_id := state.next_party_id
		state.next_party_id += 1
		state.queue.append({
			"party_id": party_id, "species_id": "pigeon", "party_count": 1, "original_party_count": 1,
			"nights_total": 1, "patience_remaining": patience_max, "patience_max": patience_max,
			"rooms_used": 0, "arrival_day": state.day,
		})

	sim.submit({"type": "set_speed", "value": speed})
	var dt := TestHelpers.tick_dt(sim)
	var guard := 0
	while not state.queue.is_empty() and guard < 2_000_000:
		guard += 1
		BotPolicy.act(sim)
		sim.advance(dt)
	BotPolicy.act(sim)

	var walked_count := 0
	for log in state.turned_away_log:
		if log["reason"] == "impatient":
			walked_count += 1
	TestHelpers.assert_eq(walked_count, 0, "QueueClearability: attentive bot at %sx should clear a max-arrivals day with zero impatient walk-aways" % speed, failures)
	TestHelpers.assert_true(state.queue.is_empty(), "QueueClearability: queue should be fully cleared at %sx" % speed, failures)
