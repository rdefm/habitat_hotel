extends GutTest

## Characterizes ticket 12's room-occupant extension of
## sim/building_layout.gd: room_occupant_placements()/room_occupant_point_local()
## (fixed in-bay spots for a built Room's guest(s), capped at
## ROOM_OCCUPANT_MAX_VISIBLE) and floor_index_for_room_type() (the elevator
## journey's floor lookup). Same shape as tests/test_lobby_guest_placement.gd
## -- literal values, no autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


func _rooms() -> Dictionary:
	var out := {}
	out["cozy_nook"] = {"name": "Cozy Nook", "unlock": {"star": 1}}
	out["roost_loft"] = {"name": "Roost Loft", "unlock": {"star": 1}}
	return out


func _floors() -> Array:
	return BuildingLayout.floors(_rooms(), 1)


## --- room_occupant_placements() / room_occupant_point_local() ---

func test_a_lone_guest_gets_one_spot_at_the_grid_origin() -> void:
	var placements := BuildingLayout.room_occupant_placements(1)

	assert_eq(placements, [BuildingLayout.ROOM_OCCUPANT_GRID_ORIGIN])


func test_two_guests_stand_side_by_side_on_the_grids_first_row() -> void:
	var placements := BuildingLayout.room_occupant_placements(2)

	assert_eq(placements.size(), 2)
	assert_eq(placements[1].y, placements[0].y)
	assert_eq(placements[1].x - placements[0].x, BuildingLayout.ROOM_OCCUPANT_GRID_SPACING.x)


func test_a_third_guest_wraps_to_a_second_row() -> void:
	var placements := BuildingLayout.room_occupant_placements(3)

	assert_eq(placements.size(), 3)
	assert_eq(placements[2].x, placements[0].x)
	assert_eq(placements[2].y - placements[0].y, BuildingLayout.ROOM_OCCUPANT_GRID_SPACING.y)


func test_party_size_beyond_the_visible_cap_still_only_shows_the_cap() -> void:
	var placements := BuildingLayout.room_occupant_placements(BuildingLayout.ROOM_OCCUPANT_MAX_VISIBLE + 2)

	assert_eq(placements.size(), BuildingLayout.ROOM_OCCUPANT_MAX_VISIBLE)


func test_zero_party_size_yields_no_spots() -> void:
	assert_eq(BuildingLayout.room_occupant_placements(0), [])


## --- resolve_room_occupant_point() ---

func test_resolve_room_occupant_point_sits_inside_its_own_bay_rect() -> void:
	var floors := _floors()
	var bay_rect: Rect2 = BuildingLayout.resolve_anchor(floors, 2, "bay_left")

	var point := BuildingLayout.resolve_room_occupant_point(floors, 2, 0, 0)

	assert_true(bay_rect.has_point(point))


func test_resolve_room_occupant_point_differs_between_bay_left_and_bay_right() -> void:
	var floors := _floors()

	var left := BuildingLayout.resolve_room_occupant_point(floors, 2, 0, 0)
	var right := BuildingLayout.resolve_room_occupant_point(floors, 2, 1, 0)

	assert_almost_eq(right.x - left.x, BuildingLayout.BAY_WIDTH, 0.01)
	assert_eq(right.y, left.y)


## --- floor_index_for_room_type() ---

func test_floor_index_for_room_type_finds_the_matching_room_floor() -> void:
	var floors := _floors()

	assert_eq(BuildingLayout.floor_index_for_room_type(floors, "cozy_nook"), 2)
	assert_eq(BuildingLayout.floor_index_for_room_type(floors, "roost_loft"), 3)


func test_floor_index_for_room_type_returns_minus_one_for_a_room_type_not_present() -> void:
	var floors := _floors()

	assert_eq(BuildingLayout.floor_index_for_room_type(floors, "ice_grotto"), -1)
