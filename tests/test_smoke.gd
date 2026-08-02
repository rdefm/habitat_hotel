extends GutTest

## Confirms the headless GUT runner can see the project's autoloads with no
## manual scene setup -- the baseline this whole test suite depends on.

func test_autoloads_are_reachable() -> void:
	assert_not_null(GameState, "GameState autoload should be reachable")
	assert_not_null(Sim, "Sim autoload should be reachable")
	assert_not_null(Clock, "Clock autoload should be reachable")
	assert_not_null(Rng, "Rng autoload should be reachable")
	assert_not_null(EventBus, "EventBus autoload should be reachable")


func test_game_state_has_loaded_data() -> void:
	assert_gt(GameState.rooms.size(), 0, "GameState.rooms should be populated from data/rooms.json")
	assert_gt(GameState.species.size(), 0, "GameState.species should be populated from data/species.json")
