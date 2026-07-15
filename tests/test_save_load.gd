class_name TestSaveLoad
extends RefCounted

const TestHelpers = preload("res://tests/test_helpers.gd")

## Part F test 2: save at night of day 3, load into a fresh SimGame, run
## both originals and loaded copies 3 more days with the same (bot)
## commands => identical state.

static func run() -> Array[String]:
	var failures: Array[String] = []
	var seed_value := 777
	var save_path := "user://test_save_load_roundtrip.json"

	var original := TestHelpers.new_sim(seed_value)
	TestHelpers.drive_until_night(original, 3)
	if not original.save_to_file(save_path):
		failures.append("SaveLoad: save_to_file failed")
		return failures

	var loaded := TestHelpers.new_sim(9999)  # different seed on purpose: load must fully overwrite it
	if not loaded.load_from_file(save_path):
		failures.append("SaveLoad: load_from_file failed")
		return failures

	if original.snapshot() != loaded.snapshot():
		failures.append("SaveLoad: loaded state does not match saved state immediately after load")
		return failures

	TestHelpers.drive_until_night(original, 6)
	TestHelpers.drive_until_night(loaded, 6)

	if original.snapshot() != loaded.snapshot():
		failures.append("SaveLoad: original and loaded-copy diverged after 3 more identical days")

	return failures
