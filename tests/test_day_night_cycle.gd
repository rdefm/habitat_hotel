extends "res://tests/helpers/sim_test_base.gd"

## Characterizes one full Morning->Midday->Evening->Night cycle via
## Clock.force_advance_day() -- the same call the headless batch runner
## uses -- now that seating is a manual action (ADR-0001) rather than
## automatic. Nothing here calls Sim.seat_party(), so every Day 1 arrival
## simply waits out its Patience during Midday and walks away by Evening,
## exactly what an unattended Reception desk produces in real play (see
## test_manual_seating.gd for the seat_party()/Patience-decay behavior
## itself, and test_checkout_review.gd for what happens once a guest IS
## seated). Values below are the deterministic output of Rng's default seed
## (1337) against a freshly reset GameState/Sim; if a legitimate change to
## demand/economy logic shifts them, re-derive by temporarily printing
## GameState.day_history from a test (gut.p(...)) and re-running via the
## command in README.md's Testing section. See
## .scratch/direct-manipulation-core-loop/issues/04-manual-seating-core.md.

func test_first_day_cycle_emits_a_day_summary_with_expected_shape() -> void:
	watch_signals(EventBus)

	Clock.force_advance_day()

	assert_signal_emit_count(EventBus, "day_summary", 1)
	assert_eq(GameState.day_history.size(), 1)

	var summary: Dictionary = GameState.day_history[0]
	assert_eq(summary["day"], 1)
	assert_eq(summary["cash_start"], 5000)
	assert_eq(summary["arrivals"], 5)
	assert_eq(summary["matched_strict"], 0, "nothing seats itself without a seat_party() call")
	assert_eq(summary["matched_mismatched"], 0)
	assert_eq(summary["walked_away_mismatch"] + summary["walked_away_full"] + summary["walked_away_too_expensive"], 5, "every unattended arrival should have walked away by Evening")
	assert_eq(summary["checkouts"], 0, "nobody was ever seated, so nobody can check out")
	assert_eq(summary["occupancy_rate"], 0.0, "no rooms were ever seated")
	assert_eq(summary["upkeep_cost"], 80, "upkeep is charged per built room regardless of occupancy")
	assert_eq(summary["wage_cost"], 175)
	assert_eq(summary["cash_end"], 5000 - 80 - 175)
	assert_eq(summary["cash_delta"], -(80 + 175))


func test_first_day_cycle_applies_its_summary_to_live_game_state() -> void:
	Clock.force_advance_day()

	assert_eq(GameState.cash, 5000 - 80 - 175)
	assert_eq(GameState.day, 2)
	assert_true(Sim.pending_arrivals.is_empty(), "Evening's expiry should leave nothing carried into day 2")
	assert_eq(count_rooms(func(r): return r["occupant"] != null), 0)
