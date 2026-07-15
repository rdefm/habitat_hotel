class_name TestDeterminism
extends RefCounted

const TestHelpers = preload("res://tests/test_helpers.gd")

## Part F test 1: same seed + same scripted command sequence for 10 days
## => byte-identical serialized final state. The bot policy is a
## deterministic function of state, so driving two fresh sims with the
## same seed through the same bot necessarily issues the same commands.

static func run() -> Array[String]:
	var failures: Array[String] = []

	var sim_a := TestHelpers.new_sim(12345)
	TestHelpers.drive_full_days(sim_a, 10)
	var snapshot_a := sim_a.snapshot()

	var sim_b := TestHelpers.new_sim(12345)
	TestHelpers.drive_full_days(sim_b, 10)
	var snapshot_b := sim_b.snapshot()

	if snapshot_a != snapshot_b:
		failures.append("Determinism: two runs with the same seed and same bot policy diverged over 10 days")

	return failures
