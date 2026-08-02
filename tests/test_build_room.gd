extends "res://tests/helpers/sim_test_base.gd"

## Characterizes GameState.build_room()'s flat-slot addressing (data/slot_layout.json
## + hotel_rooms keyed by a single global slot integer) before it's replaced by
## per-Floor instance addressing (see .scratch/direct-manipulation-core-loop/issues/02-floor-data-model.md).

func test_builds_room_into_unlocked_empty_slot() -> void:
	assert_true(GameState.room_at_slot(4).is_empty(), "slot 4 should start empty")
	var cash_before: int = GameState.cash

	var built := GameState.build_room(4, "cozy_nook")

	assert_true(built, "building into an unlocked, empty, affordable slot should succeed")
	assert_eq(GameState.cash, cash_before - 800, "build_cost should be deducted from cash")
	var room := GameState.room_at_slot(4)
	assert_eq(room["room_type_id"], "cozy_nook")
	assert_eq(room["occupant"], null)
	assert_eq(room["upgrades"], [])
	assert_false(room["needs_cleaning"])


func test_build_fails_into_locked_slot() -> void:
	# Slot 6 requires star 2; a fresh game starts at star 1.
	var cash_before: int = GameState.cash

	var built := GameState.build_room(6, "cozy_nook")

	assert_false(built, "a slot locked above the current star should refuse to build")
	assert_eq(GameState.cash, cash_before, "a failed build should have no side effects")
	assert_true(GameState.room_at_slot(6).is_empty())


func test_build_fails_into_already_occupied_slot() -> void:
	# Slot 0 is occupied by the starting hotel's cozy_nook.
	var cash_before: int = GameState.cash

	var built := GameState.build_room(0, "roost_loft")

	assert_false(built, "an already-built slot should refuse a second room")
	assert_eq(GameState.cash, cash_before)
	assert_eq(GameState.room_at_slot(0)["room_type_id"], "cozy_nook", "the original room should be untouched")


func test_build_fails_for_room_type_not_yet_unlocked() -> void:
	# ice_grotto requires star 2; a fresh game starts at star 1.
	var built := GameState.build_room(4, "ice_grotto")

	assert_false(built, "a room type above the current star should refuse to build")
	assert_true(GameState.room_at_slot(4).is_empty())


func test_build_fails_when_cash_insufficient() -> void:
	GameState.cash = 100 # cozy_nook costs 800

	var built := GameState.build_room(4, "cozy_nook")

	assert_false(built, "an unaffordable build should refuse")
	assert_eq(GameState.cash, 100, "cash should be untouched on a failed build")
	assert_true(GameState.room_at_slot(4).is_empty())
