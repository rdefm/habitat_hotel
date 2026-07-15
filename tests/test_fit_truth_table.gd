class_name TestFitTruthTable
extends RefCounted

const TestHelpers = preload("res://tests/test_helpers.gd")
const SimMatching = preload("res://sim/sim_matching.gd")

## Part F test 3: every species x every room => assert expected
## GOLD/AMBER/NONE. Doubles as a design-data regression test.

static func run() -> Array[String]:
	var failures: Array[String] = []
	var sim := TestHelpers.new_sim(1)
	var content := sim.get_content()

	for species_id in content.species.keys():
		var species: Dictionary = content.species[species_id]
		for room_type_id in content.rooms.keys():
			var room_type: Dictionary = content.rooms[room_type_id]
			var room := {"plot_id": 0, "room_type": room_type_id, "state": "vacant", "stay_id": -1}
			var fit := SimMatching.evaluate_fit(room, room_type, species, 1)
			var missing := SimMatching.missing_needs(room_type["tags"], species["needs"])
			var expected := "GOLD" if missing.is_empty() else "AMBER"
			TestHelpers.assert_eq(fit, expected, "Fit truth table: %s x %s" % [species_id, room_type_id], failures)

	# Named regression call-out from the brief.
	var flamingo_fit := SimMatching.evaluate_fit(
		{"plot_id": 0, "room_type": "veranda_suite", "state": "vacant", "stay_id": -1},
		content.rooms["veranda_suite"], content.species["flamingo"], 2)
	TestHelpers.assert_eq(flamingo_fit, "GOLD", "Fit truth table: flamingo x veranda_suite must be GOLD", failures)

	# NONE conditions: a room that isn't vacant+clean never glows, regardless of tags.
	for bad_state in ["occupied", "dirty", "cleaning", "empty"]:
		var room2 := {"plot_id": 0, "room_type": "veranda_suite", "state": bad_state, "stay_id": -1}
		var fit2 := SimMatching.evaluate_fit(room2, content.rooms["veranda_suite"], content.species["flamingo"], 2)
		TestHelpers.assert_eq(fit2, "NONE", "Fit truth table: room state '%s' should be NONE" % bad_state, failures)

	return failures
