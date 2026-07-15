extends SceneTree

## Headless entry point: `godot --headless --script res://tests/run_tests.gd`
## Exit code 0 on pass, non-zero with readable failure output otherwise.

const TestDeterminism = preload("res://tests/test_determinism.gd")
const TestSaveLoad = preload("res://tests/test_save_load.gd")
const TestFitTruthTable = preload("res://tests/test_fit_truth_table.gd")
const TestPartySplit = preload("res://tests/test_party_split.gd")
const TestCleaningRace = preload("res://tests/test_cleaning_race.gd")
const TestQueueClearability = preload("res://tests/test_queue_clearability.gd")
const TestNoSpaceDay = preload("res://tests/test_no_space_day.gd")
const TestTenDaySoak = preload("res://tests/test_ten_day_soak.gd")

func _initialize() -> void:
	var suites := {
		"1. Determinism": TestDeterminism,
		"2. Save/load roundtrip": TestSaveLoad,
		"3. Fit truth table": TestFitTruthTable,
		"4. Party split + partial seating": TestPartySplit,
		"5. Cleaning race pacing": TestCleaningRace,
		"6. Queue clearability": TestQueueClearability,
		"7. No-space day": TestNoSpaceDay,
		"8. Ten-day soak": TestTenDaySoak,
	}

	var total_failures := 0
	for suite_name in suites.keys():
		var failures: Array[String] = suites[suite_name].run()
		if failures.is_empty():
			print("[PASS] %s" % suite_name)
		else:
			print("[FAIL] %s (%d failure(s))" % [suite_name, failures.size()])
			for f in failures:
				print("    - %s" % f)
			total_failures += failures.size()

	if total_failures == 0:
		print("\nAll tests passed.")
		quit(0)
	else:
		print("\n%d total failure(s)." % total_failures)
		quit(1)
