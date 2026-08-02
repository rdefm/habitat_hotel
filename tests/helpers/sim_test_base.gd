extends GutTest

## Shared setup for tests that drive the sim autoloads (GameState/Sim/Clock/
## Rng) through a full day/night cycle. Mirrors BatchRunner.run()'s reset
## sequence so every test starts from the same deterministic day-1 state,
## regardless of test order or what an earlier test left behind.
##
## Subclasses that override before_each() must call super.before_each()
## first to get this reset.

func before_each() -> void:
	Rng.reset()
	Clock.reset()
	GameState.reset_to_starting_conditions()
	Sim.reset()
