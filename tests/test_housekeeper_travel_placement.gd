extends GutTest

## Characterizes ticket 13's Staffer Job travel extension of
## sim/building_layout.gd: resolve_room_housekeeper_point() gives a
## Housekeeping Staffer a fixed in-bay spot to work at, distinct from the
## guest occupant grid's own spots so a Staffer working an occupied-at-
## checkout Room never visually overlaps a settled guest. Same shape as
## tests/test_room_occupant_placement.gd -- literal values, no autoloads, no
## nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


func _rooms() -> Dictionary:
	var out := {}
	out["cozy_nook"] = {"name": "Cozy Nook", "unlock": {"star": 1}}
	out["roost_loft"] = {"name": "Roost Loft", "unlock": {"star": 1}}
	return out


func _floors() -> Array:
	return BuildingLayout.floors(_rooms(), 1)


func test_resolve_room_housekeeper_point_sits_inside_its_own_bay_rect() -> void:
	var floors := _floors()
	var bay_rect: Rect2 = BuildingLayout.resolve_anchor(floors, 2, "bay_left")

	var point := BuildingLayout.resolve_room_housekeeper_point(floors, 2, 0)

	assert_true(bay_rect.has_point(point))


func test_resolve_room_housekeeper_point_differs_between_bay_left_and_bay_right() -> void:
	var floors := _floors()

	var left := BuildingLayout.resolve_room_housekeeper_point(floors, 2, 0)
	var right := BuildingLayout.resolve_room_housekeeper_point(floors, 2, 1)

	assert_almost_eq(right.x - left.x, BuildingLayout.BAY_WIDTH, 0.01)
	assert_eq(right.y, left.y)


## Distinct from the occupant grid's own spots (ROOM_OCCUPANT_GRID_ORIGIN's
## two columns at local x=30/120) so a Housekeeper working an occupied Room
## (e.g. mid-checkout) never stands on top of a settled guest.
func test_resolve_room_housekeeper_point_does_not_collide_with_the_occupant_grid() -> void:
	var floors := _floors()

	var housekeeper_point := BuildingLayout.resolve_room_housekeeper_point(floors, 2, 0)
	for member_index in range(BuildingLayout.ROOM_OCCUPANT_MAX_VISIBLE):
		var occupant_point := BuildingLayout.resolve_room_occupant_point(floors, 2, 0, member_index)
		assert_true(housekeeper_point.distance_to(occupant_point) > 20.0)
