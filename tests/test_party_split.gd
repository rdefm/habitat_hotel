class_name TestPartySplit
extends RefCounted

const TestHelpers = preload("res://tests/test_helpers.gd")

## Part F test 4: a 6-pigeon party across two rooms produces correct
## occupancy and correct satisfaction penalties; partial seating produces
## a walked remainder with no extra penalties.

static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_split_across_two_rooms(failures)
	_test_partial_seating_walk(failures)
	return failures

static func _test_split_across_two_rooms(failures: Array[String]) -> void:
	var sim := TestHelpers.new_sim(1)
	var state := sim.get_state()
	var balance: Dictionary = sim.get_content().balance
	state.queue.clear()
	state.queue.append({
		"party_id": 9001, "species_id": "pigeon", "party_count": 6, "original_party_count": 6,
		"nights_total": 2, "patience_remaining": 999.0, "patience_max": 999.0, "rooms_used": 0, "arrival_day": state.day,
	})

	# pigeon needs high_perch; lagoon_room has neither -> always amber (missing=1) here.
	var expected_first := clampf(float(balance["satisfaction_base"]) - float(balance["amber_missing_need_satisfaction_penalty"]) - float(balance["partial_seating_satisfaction_penalty"]), 0.0, float(balance["satisfaction_cap"]))
	var expected_second := clampf(float(balance["satisfaction_base"]) - float(balance["amber_missing_need_satisfaction_penalty"]) - float(balance["party_split_satisfaction_penalty"]), 0.0, float(balance["satisfaction_cap"]))

	# plots 2 and 3 are the two prebuilt lagoon_rooms (capacity 3 each).
	var r1 := sim.submit({"type": "seat_guest", "party_id": 9001, "plot_id": 2})
	if not bool(r1.get("ok", false)):
		failures.append("PartySplit: first seat should succeed, got %s" % str(r1))
		return
	var stay1: Dictionary = state.stays[str(int(r1["stay_id"]))]
	TestHelpers.assert_eq(int(stay1["party_count"]), 3, "PartySplit: first room should seat 3 of 6", failures)
	TestHelpers.assert_eq(int(r1["remainder"]), 3, "PartySplit: 3 pigeons should remain queued after first seat", failures)
	TestHelpers.assert_true(absf(float(stay1["satisfaction"]) - expected_first) < 0.001, "PartySplit: first stay satisfaction expected %s got %s" % [expected_first, stay1["satisfaction"]], failures)

	var r2 := sim.submit({"type": "seat_guest", "party_id": 9001, "plot_id": 3})
	if not bool(r2.get("ok", false)):
		failures.append("PartySplit: second seat should succeed, got %s" % str(r2))
		return
	var stay2: Dictionary = state.stays[str(int(r2["stay_id"]))]
	TestHelpers.assert_eq(int(stay2["party_count"]), 3, "PartySplit: second room should seat the remaining 3", failures)
	TestHelpers.assert_eq(int(r2["remainder"]), 0, "PartySplit: party should be fully seated after second room", failures)
	TestHelpers.assert_true(absf(float(stay2["satisfaction"]) - expected_second) < 0.001, "PartySplit: second stay satisfaction expected %s got %s" % [expected_second, stay2["satisfaction"]], failures)

	var still_queued := false
	for entry in state.queue:
		if int(entry["party_id"]) == 9001:
			still_queued = true
	TestHelpers.assert_true(not still_queued, "PartySplit: party 9001 should be removed from queue once fully seated", failures)
	TestHelpers.assert_eq(int(stay1["party_count"]) + int(stay2["party_count"]), 6, "PartySplit: total seated across both rooms should equal the original party of 6", failures)

static func _test_partial_seating_walk(failures: Array[String]) -> void:
	var sim := TestHelpers.new_sim(2)
	var state := sim.get_state()
	var balance: Dictionary = sim.get_content().balance
	var dt := TestHelpers.tick_dt(sim)
	state.queue.clear()
	state.queue.append({
		"party_id": 9002, "species_id": "pigeon", "party_count": 4, "original_party_count": 4,
		"nights_total": 1, "patience_remaining": dt * 0.5, "patience_max": dt * 0.5, "rooms_used": 0, "arrival_day": state.day,
	})

	var expected := clampf(float(balance["satisfaction_base"]) - float(balance["amber_missing_need_satisfaction_penalty"]) - float(balance["partial_seating_satisfaction_penalty"]), 0.0, float(balance["satisfaction_cap"]))

	# plot 0 is the prebuilt cozy_nook (capacity 2) -- only half the party fits.
	var r := sim.submit({"type": "seat_guest", "party_id": 9002, "plot_id": 0})
	if not bool(r.get("ok", false)):
		failures.append("PartySplit(partial): seat should succeed, got %s" % str(r))
		return
	var stay: Dictionary = state.stays[str(int(r["stay_id"]))]
	TestHelpers.assert_eq(int(stay["party_count"]), 2, "PartySplit(partial): cozy_nook should seat 2 of 4", failures)
	TestHelpers.assert_true(absf(float(stay["satisfaction"]) - expected) < 0.001, "PartySplit(partial): satisfaction expected %s got %s" % [expected, stay["satisfaction"]], failures)

	var cash_before_walk := state.cash
	sim.advance(dt + 0.001)  # exactly one tick: the remainder's patience is already spent

	var walked := false
	for log in state.turned_away_log:
		if int(log.get("party_id", -1)) == 9002 and log["reason"] == "impatient":
			walked = true
			TestHelpers.assert_eq(int(log["party_count"]), 2, "PartySplit(partial): the walked remainder should be exactly 2", failures)
	TestHelpers.assert_true(walked, "PartySplit(partial): remainder of 2 should walk away impatient with no other penalty", failures)
	TestHelpers.assert_eq(state.cash, cash_before_walk, "PartySplit(partial): a walked remainder costs no cash beyond the missed revenue (no direct penalty)", failures)

	var stay_after: Dictionary = state.stays[str(int(r["stay_id"]))]
	TestHelpers.assert_true(absf(float(stay_after["satisfaction"]) - expected) < 0.001, "PartySplit(partial): the seated stay's satisfaction must not change after the remainder walks (penalty applied once, at seat time)", failures)
