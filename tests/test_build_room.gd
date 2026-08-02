extends "res://tests/helpers/sim_test_base.gd"

## Characterizes GameState.build_room()'s per-Floor instance addressing --
## data/slot_layout.json (the flat, generic per-slot unlock table) is gone;
## each Room type's own unlock.star field gates its Floor directly, and a new
## max_instances field caps how many times that Floor can be built out. Built
## instances are addressed by room_type_id + a stable per-type instance_id
## instead of a single global slot integer. See
## .scratch/direct-manipulation-core-loop/issues/02-floor-data-model.md.

func test_builds_room_into_an_unlocked_floor_under_its_instance_cap() -> void:
	assert_eq(GameState.floor_instance_count("cozy_nook"), 1, "starting hotel has one cozy_nook already")
	var cash_before: int = GameState.cash

	var built := GameState.build_room("cozy_nook")

	assert_true(built, "building an unlocked, under-cap, affordable Floor should succeed")
	assert_eq(GameState.cash, cash_before - 800, "build_cost should be deducted from cash")
	var room := GameState.room_instance("cozy_nook", 1)
	assert_false(room.is_empty(), "the new instance should be addressable as cozy_nook instance 1")
	assert_eq(room["room_type_id"], "cozy_nook")
	assert_eq(room["instance_id"], 1)
	assert_eq(room["occupant"], null)
	assert_eq(room["upgrades"], [])
	assert_false(room["needs_cleaning"])


func test_build_fails_once_a_floors_instance_cap_is_reached() -> void:
	# lagoon_room starts with 2 built instances and a max_instances of 4.
	assert_true(GameState.build_room("lagoon_room"))
	assert_true(GameState.build_room("lagoon_room"))
	assert_eq(GameState.floor_instance_count("lagoon_room"), 4, "lagoon_room's Floor should now be at its cap")
	var cash_before: int = GameState.cash

	var built := GameState.build_room("lagoon_room")

	assert_false(built, "building past a Floor's instance cap should refuse, with no side effects")
	assert_eq(GameState.cash, cash_before)
	assert_eq(GameState.floor_instance_count("lagoon_room"), 4)


func test_build_fails_for_a_room_type_not_yet_star_unlocked() -> void:
	# ice_grotto requires star 2; a fresh game starts at star 1.
	var cash_before: int = GameState.cash

	var built := GameState.build_room("ice_grotto")

	assert_false(built, "a Floor above the current star should refuse to build")
	assert_eq(GameState.cash, cash_before, "a failed build should have no side effects")
	assert_eq(GameState.floor_instance_count("ice_grotto"), 0)


func test_floor_stays_locked_until_its_star_requirement_is_met() -> void:
	assert_false(GameState.can_build_room_type("ice_grotto"), "a star-2 Floor should be locked at the starting star 1")

	GameState.stars = 2

	assert_true(GameState.can_build_room_type("ice_grotto"), "the Floor should unlock once its star requirement is met")
	assert_true(GameState.build_room("ice_grotto"))


func test_build_fails_when_cash_insufficient() -> void:
	GameState.cash = 100 # cozy_nook costs 800

	var built := GameState.build_room("cozy_nook")

	assert_false(built, "an unaffordable build should refuse")
	assert_eq(GameState.cash, 100, "cash should be untouched on a failed build")
	assert_eq(GameState.floor_instance_count("cozy_nook"), 1, "no new instance should have been added")
