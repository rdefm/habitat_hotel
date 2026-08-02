extends "res://tests/helpers/sim_test_base.gd"

## Characterizes one full Morning->Midday->Evening->Night cycle producing a
## day summary via Clock.force_advance_day() -- the same call the headless
## batch runner uses. Values below are the deterministic output of Rng's
## default seed (1337) against a freshly reset GameState/Sim; if a legitimate
## change to demand/matching/economy logic shifts them, re-derive by
## temporarily printing GameState.day_history/review_history from a test
## (gut.p(...)) and re-running via the command in README.md's Testing section.

func test_first_day_cycle_emits_a_day_summary_with_expected_shape() -> void:
	watch_signals(EventBus)

	Clock.force_advance_day()

	assert_signal_emit_count(EventBus, "day_summary", 1)
	assert_eq(GameState.day_history.size(), 1)

	var summary: Dictionary = GameState.day_history[0]
	assert_eq(summary["day"], 1)
	assert_eq(summary["cash_start"], 5000)
	assert_eq(summary["cash_end"], 4745)
	assert_eq(summary["cash_delta"], -255)
	assert_eq(summary["arrivals"], 5)
	assert_eq(summary["matched_strict"], 3)
	assert_eq(summary["matched_mismatched"], 1)
	assert_eq(summary["walked_away_mismatch"], 0)
	assert_eq(summary["walked_away_full"], 1)
	assert_eq(summary["walked_away_too_expensive"], 0)
	assert_eq(summary["checkouts"], 0, "no guest has stayed long enough to check out on day 1")
	assert_eq(summary["occupancy_rate"], 1.0, "day 1's 4 admissions exactly fill the 4 starting rooms")
	assert_eq(summary["upkeep_cost"], 80)
	assert_eq(summary["wage_cost"], 175)


func test_first_day_cycle_applies_its_summary_to_live_game_state() -> void:
	Clock.force_advance_day()

	assert_eq(GameState.cash, 4745, "GameState.cash should reflect the day's revenue/upkeep/wage, not just the summary dict")
	assert_eq(GameState.day, 2)
	assert_eq(count_rooms(func(r): return r["occupant"] != null), 4)
