class_name TestHelpers
extends RefCounted

const SimGame = preload("res://sim/sim_game.gd")
const BotPolicy = preload("res://tests/bot_policy.gd")

## Shared plumbing for the headless test suite: assertions and bot-driven
## sim runners. sim/ is pure RefCounted, so tests construct SimGame
## directly and drive it with advance(dt) + submit(command) -- no scene
## tree needed (Part F).

static func assert_true(condition: bool, message: String, failures: Array) -> void:
	if not condition:
		failures.append(message)

static func assert_eq(actual, expected, message: String, failures: Array) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])

static func new_sim(seed_value: int) -> SimGame:
	return SimGame.new("res://data", seed_value)

static func tick_dt(sim: SimGame) -> float:
	return 1.0 / float(sim.get_content().balance.get("ticks_per_sim_second", 8))

## Drives sim (bot-piloted) forward until it is at Night of `target_day`,
## stopping before the next_day command that would leave that night.
static func drive_until_night(sim: SimGame, target_day: int, bot: bool = true) -> void:
	var dt := tick_dt(sim)
	var guard := 0
	while not (sim.get_state().day == target_day and sim.get_state().phase == "night"):
		guard += 1
		if guard > 2_000_000:
			push_error("TestHelpers.drive_until_night: exceeded iteration guard, likely stuck")
			return
		if sim.get_state().phase == "night":
			sim.submit({"type": "next_day"})
			continue
		if bot:
			BotPolicy.act(sim)
		sim.advance(dt)

## Drives sim (bot-piloted) through full completion of day `days` (i.e. from
## a fresh sim, simulates days 1..days and stops right as day `days + 1`
## begins).
static func drive_full_days(sim: SimGame, days: int, bot: bool = true) -> void:
	var dt := tick_dt(sim)
	var guard := 0
	while sim.get_state().day <= days:
		guard += 1
		if guard > 2_000_000:
			push_error("TestHelpers.drive_full_days: exceeded iteration guard, likely stuck")
			return
		if sim.get_state().phase == "night":
			sim.submit({"type": "next_day"})
			continue
		if bot:
			BotPolicy.act(sim)
		sim.advance(dt)
