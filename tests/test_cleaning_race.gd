class_name TestCleaningRace
extends RefCounted

const TestHelpers = preload("res://tests/test_helpers.gd")

## Part F test 5: with 4 morning checkouts, the last clean_finished should
## land inside the afternoon phase -- not before it starts, not after it
## ends. This is the balance instrument for the day's core tension.

static func run() -> Array[String]:
	var failures: Array[String] = []
	var sim := TestHelpers.new_sim(1)
	var state := sim.get_state()
	var balance: Dictionary = sim.get_content().balance

	# Occupy all 4 starting rooms with stays that check out on day 2.
	for room in state.rooms:
		var stay_id := state.next_stay_id
		state.next_stay_id += 1
		state.stays[str(stay_id)] = {
			"stay_id": stay_id, "plot_id": room["plot_id"], "species_id": "pigeon",
			"party_count": 1, "nights_total": 1, "day_seated": 1, "day_checkout": 2,
			"satisfaction": 70.0, "original_party_id": -1, "needs_missing": 0, "likes_met": 0,
		}
		room["state"] = "occupied"
		room["stay_id"] = stay_id

	TestHelpers.drive_until_night(sim, 1, false)
	var next_day_result := sim.submit({"type": "next_day"})
	TestHelpers.assert_true(bool(next_day_result.get("ok", false)), "CleaningRace: next_day into day 2 should succeed", failures)
	sim.drain_events()

	var dirty_count := 0
	for room in state.rooms:
		if room["state"] == "dirty" or room["state"] == "cleaning":
			dirty_count += 1
	TestHelpers.assert_eq(dirty_count, 4, "CleaningRace: all 4 rooms should be dirty right after checkout", failures)

	var dt := TestHelpers.tick_dt(sim)
	var lengths: Dictionary = balance.get("phase_lengths_sim_seconds", {})
	var afternoon_start := float(lengths.get("morning", 30.0))
	var afternoon_end := afternoon_start + float(lengths.get("afternoon", 50.0))

	var last_clean_finished_at := -1.0
	var elapsed := 0.0
	var guard := 0
	while last_clean_finished_at < 0.0 and guard < 2_000_000:
		guard += 1
		sim.advance(dt)
		elapsed += dt
		sim.drain_events()
		if state.cleaning_plot_id == -1 and state.housekeeping_order.is_empty():
			var all_clean := true
			for room in state.rooms:
				if room["state"] != "vacant":
					all_clean = false
			if all_clean:
				last_clean_finished_at = elapsed

	TestHelpers.assert_true(last_clean_finished_at > 0.0, "CleaningRace: housekeeping should finish all 4 rooms within a bounded time", failures)
	TestHelpers.assert_true(last_clean_finished_at >= afternoon_start, "CleaningRace: last room finished too early, at %s sim-sec (afternoon starts at %s)" % [last_clean_finished_at, afternoon_start], failures)
	TestHelpers.assert_true(last_clean_finished_at <= afternoon_end, "CleaningRace: last room finished too late, at %s sim-sec (afternoon ends at %s)" % [last_clean_finished_at, afternoon_end], failures)

	return failures
