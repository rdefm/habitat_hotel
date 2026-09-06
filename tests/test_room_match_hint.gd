extends GutTest

## Characterizes ticket 11's extension of sim/building_layout.gd:
## room_bay_match_hint(), the per-bay Match hint state a lobby-guest
## selection/drag surfaces as a bay glow (ADR-0001/0009). Same shape as
## tests/test_room_bays.gd -- literal values in, a stubbed hint_fn standing
## in for Sim.match_hint() (the real authority), no autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


func test_no_selected_party_never_glows_and_never_calls_the_hint_fn() -> void:
	var called := false
	var hint := BuildingLayout.room_bay_match_hint(-1, "cozy_nook", 0, func(_p, _r, _i):
		called = true
		return "green"
	)

	assert_eq(hint, "none")
	assert_false(called, "no Party is selected, so there is nothing to hint against")


func test_a_full_match_surfaces_green_from_the_hint_fn() -> void:
	var hint := BuildingLayout.room_bay_match_hint(1, "cozy_nook", 0, func(_p, _r, _i): return "green")

	assert_eq(hint, "green")


func test_a_partial_match_surfaces_amber_from_the_hint_fn() -> void:
	var hint := BuildingLayout.room_bay_match_hint(1, "cozy_nook", 0, func(_p, _r, _i): return "amber")

	assert_eq(hint, "amber")


func test_an_unseatable_room_surfaces_none_from_the_hint_fn() -> void:
	var hint := BuildingLayout.room_bay_match_hint(1, "cozy_nook", 0, func(_p, _r, _i): return "none")

	assert_eq(hint, "none")


func test_hint_fn_is_called_with_the_selected_party_and_the_bays_own_room() -> void:
	var seen_args := []
	BuildingLayout.room_bay_match_hint(7, "ice_grotto", 1, func(p, r, i):
		seen_args.append([p, r, i])
		return "green"
	)

	assert_eq(seen_args, [[7, "ice_grotto", 1]])
