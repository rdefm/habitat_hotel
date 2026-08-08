extends "res://tests/helpers/sim_test_base.gd"

## Ticket 15 -- full headless multi-day integration check: proves Floors
## (ticket 02/04), Stations/Roster (ticket 07), manual seating (ticket 04),
## and the full Dining loop (tickets 09-12) cooperate over many unattended
## days through BatchRunner.run() -- the same headless tool the project's
## balancing workflow depends on (see sim/batch_runner.gd). Deliberately
## drives everything through the two shared paths those tickets already
## established -- Sim.seat_party() (via BatchRunner's ticket-06 scripted
## autopilot) and Sim.assign_staffer() -- rather than any new admission or
## dining-resolution logic of its own.
##
## Starting Roster only covers 3 of 4 Stations at once (data/staffers.json:
## Biscuit/Marlon/Shelly). BatchRunner.run()'s default leaves Kitchen empty
## (matching interactive play's starting coverage), which would mean Dining
## never actually serves anyone in a batch run -- so this test passes
## {"marlon": "kitchen"} (Marlon's the only Staffer whose kitchen skill, 3,
## clears stations.kitchen.dinner_min_skill) to actually exercise Dining
## service, at the cost of leaving Bellhop unstaffed for the run (just a
## flat check-in delay -- see sim_controller.gd's _start_checkin(), nothing
## that can strand a guest).

const BatchRunner = preload("res://sim/batch_runner.gd")
const RUN_DAYS := 60
const CSV_PATH := "user://test_integration_multiday.csv"
const SEED := 12345
# Marlon's kitchen skill (3) is the only starting Staffer clearing
# stations.kitchen.dinner_min_skill -- see test_dining_reputation.gd.
const KITCHEN_STAFFED := {"marlon": "kitchen"}


func test_60_day_run_with_full_station_coverage_resolves_every_party_and_dining_guest() -> void:
	var rows := BatchRunner.run(RUN_DAYS, CSV_PATH, SEED, KITCHEN_STAFFED)

	assert_eq(rows.size(), RUN_DAYS, "one summary row per simulated day")
	assert_true(Sim.pending_arrivals.is_empty(), "no Room-booking Party should be left stranded after the run")
	assert_true(Sim.walkin_queue.is_empty(), "no dining guest should be left stranded after the run")

	var total_checkouts := 0
	var total_dining_served := 0
	var total_dining_walked_away := 0
	var prev_cash_end: int = int(rows[0]["cash_start"])
	var prev_hearts: int = int(rows[0]["hearts"])

	for row in rows:
		assert_between(int(row["reputation"]), 0, 100, "day %d: reputation should stay in its 0-100 meter" % int(row["day"]))
		# cash_end/cash_start continuity across day boundaries: Floors' upkeep,
		# Checkout revenue, and wages all landed on the same ledger, day after day.
		assert_eq(int(row["cash_start"]), prev_cash_end, "day %d: cash_start should pick up where the previous day's cash_end left off" % int(row["day"]))
		prev_cash_end = int(row["cash_end"])
		# Hearts only ever accumulate (Satisfaction.hearts_for() is never subtracted).
		assert_gte(int(row["hearts"]), prev_hearts, "day %d: Hearts should never decrease" % int(row["day"]))
		prev_hearts = int(row["hearts"])

		total_checkouts += int(row["checkouts"])
		total_dining_served += int(row["dining_served"])
		total_dining_walked_away += int(row["dining_walked_away"])

	assert_gt(total_checkouts, 0, "Floors/Rooms should have produced completed stays across 60 days")
	assert_gt(total_dining_served, 0, "a Kitchen-staffed run should have actually served Dining guests, not just queued and lost them")
	assert_gt(total_dining_served + total_dining_walked_away, 0, "the Evening Dining loop should have run across 60 days")


func test_the_runs_csv_output_reflects_dining_activity_alongside_checkout_driven_deltas() -> void:
	BatchRunner.run(RUN_DAYS, CSV_PATH, SEED, KITCHEN_STAFFED)

	var file := FileAccess.open(CSV_PATH, FileAccess.READ)
	assert_not_null(file, "the batch run should have written a CSV to %s" % CSV_PATH)
	if file == null:
		return

	var header := file.get_line().split(",")
	file.close()

	for column in ["dining_served", "dining_positive_reviews", "dining_neutral_reviews", "dining_negative_reviews", "dining_walked_away"]:
		assert_true(header.has(column), "CSV header should surface Dining activity (%s), not just legacy room/guest metrics" % column)
	for column in ["hearts", "reputation", "positive_reviews", "negative_reviews"]:
		assert_true(header.has(column), "CSV header should still carry Checkout-driven Reputation/Hearts columns (%s) alongside Dining's" % column)


func test_a_default_coverage_run_still_completes_with_no_second_admission_or_dining_resolution_path() -> void:
	# No station_assignments override -- BatchRunner.run()'s untouched default
	# (Kitchen left empty, matching interactive play's starting coverage).
	# Dining guests should still queue and resolve (via Patience walk-away)
	# through the same single _decay_walkin_patience()/_tick_dinner() pipeline,
	# proving ticket 06's "shared seat action + scripted autopilot rule, no
	# second path" guarantee holds even when Kitchen never gets staffed.
	var rows := BatchRunner.run(RUN_DAYS, CSV_PATH, SEED)

	assert_eq(rows.size(), RUN_DAYS)
	assert_true(Sim.pending_arrivals.is_empty())
	assert_true(Sim.walkin_queue.is_empty())

	var total_dining_served := 0
	for row in rows:
		total_dining_served += int(row["dining_served"])
	assert_eq(total_dining_served, 0, "an unstaffed Kitchen should never serve a Dining guest")
