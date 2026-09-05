extends GutTest

## Characterizes sim/building_layout.gd's pure static functions -- the one
## new seam ticket 04 (ADR-0020) introduces. Mirrors tests/test_match_hint.gd's
## shape: literal hand-built `rooms` dicts and plain `stars` ints in, no
## autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


## A minimal rooms catalog whose array-order-vs-alphabetical distinction
## matters: dict insertion order is z_room (star 1), a_room (star 1), then
## b_room (star 2) -- alphabetical would read a_room, b_room, z_room, but
## the real ordering rule is ascending star with ties broken by insertion
## (array) order.
func _rooms() -> Dictionary:
	var out := {}
	out["z_room"] = {"name": "Zebra Suite", "unlock": {"star": 1}}
	out["a_room"] = {"name": "Antelope Den", "unlock": {"star": 1}}
	out["b_room"] = {"name": "Baboon Loft", "unlock": {"star": 2}}
	return out


## --- unlocked_room_type_ids_ascending() / floors(): ordering ---

func test_ties_break_by_array_order_not_alphabetical() -> void:
	var ids := BuildingLayout.unlocked_room_type_ids_ascending(_rooms(), 1)

	assert_eq(ids, ["z_room", "a_room"], "both are star 1; z_room precedes a_room in the catalog, so it must stay first despite the alphabetical difference")


func test_higher_star_room_types_sort_after_lower_star_ones() -> void:
	var ids := BuildingLayout.unlocked_room_type_ids_ascending(_rooms(), 2)

	assert_eq(ids, ["z_room", "a_room", "b_room"])


func test_a_room_type_above_the_current_star_is_excluded() -> void:
	var ids := BuildingLayout.unlocked_room_type_ids_ascending(_rooms(), 1)

	assert_false(ids.has("b_room"), "b_room needs star 2 and shouldn't appear at star 1")


func test_floors_stacks_reception_then_terrace_then_rooms_ascending() -> void:
	var floors := BuildingLayout.floors(_rooms(), 2)

	assert_eq(floors.size(), 5)
	assert_eq(floors[0]["kind"], "reception")
	assert_eq(floors[1]["kind"], "terrace")
	assert_eq(floors[2]["room_type_id"], "z_room")
	assert_eq(floors[3]["room_type_id"], "a_room")
	assert_eq(floors[4]["room_type_id"], "b_room")


## --- Level numbering ---

func test_reception_is_the_unnumbered_ground_floor() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	assert_eq(floors[0]["level"], BuildingLayout.GROUND_FLOOR_LEVEL)
	assert_eq(floors[0]["sign_text"], "Reception", "Reception's sign carries no level number")


func test_terrace_is_always_level_one() -> void:
	var floors := BuildingLayout.floors(_rooms(), 3)

	assert_eq(floors[1]["kind"], "terrace")
	assert_eq(floors[1]["level"], 1)


func test_room_floors_number_upward_from_the_terrace() -> void:
	var floors := BuildingLayout.floors(_rooms(), 2)

	assert_eq(floors[2]["level"], 2)
	assert_eq(floors[3]["level"], 3)
	assert_eq(floors[4]["level"], 4)


func test_unlocking_a_new_floor_leaves_every_existing_level_number_unchanged() -> void:
	var before := BuildingLayout.floors(_rooms(), 1)
	var after := BuildingLayout.floors(_rooms(), 2)

	for i in range(before.size()):
		assert_eq(after[i]["level"], before[i]["level"], "floor %d's level must not shift when a higher floor unlocks" % i)
	assert_eq(after.size(), before.size() + 1)
	assert_eq(after[after.size() - 1]["room_type_id"], "b_room", "the newly unlocked floor lands on top")


## --- Band composition ---

func test_reception_and_terrace_use_the_full_painted_band() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	assert_eq(floors[0]["band_variant"], "full")
	assert_eq(floors[1]["band_variant"], "full")


func test_room_floors_use_the_tiled_column_and_shaft_band() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	assert_eq(floors[2]["band_variant"], "tiled")


func test_room_floor_sign_names_its_level_and_room_type() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	assert_eq(floors[2]["sign_text"], "Level 2 — Zebra Suite")


## --- Fit-all bounds ---

func test_fit_all_bounds_widens_to_the_building_width() -> void:
	var bounds := BuildingLayout.fit_all_bounds(BuildingLayout.floors(_rooms(), 1))

	assert_eq(bounds.size.x, BuildingLayout.BUILDING_WIDTH)


func test_fit_all_bounds_grows_upward_as_a_floor_unlocks() -> void:
	var before := BuildingLayout.fit_all_bounds(BuildingLayout.floors(_rooms(), 1))
	var after := BuildingLayout.fit_all_bounds(BuildingLayout.floors(_rooms(), 2))

	assert_eq(after.position.y, before.position.y - BuildingLayout.ROOM_FLOOR_HEIGHT, "the top edge should move up by exactly the new floor's height")
	assert_eq(after.position.x, before.position.x)
	assert_eq(before.position.y + before.size.y, 0.0, "the ground plinth's bottom edge always sits at world y=0")
	assert_eq(after.position.y + after.size.y, 0.0)


func test_floor_bottom_y_is_stable_for_existing_floors_when_one_unlocks() -> void:
	var before := BuildingLayout.floors(_rooms(), 1)
	var after := BuildingLayout.floors(_rooms(), 2)

	for i in range(before.size()):
		assert_eq(BuildingLayout.floor_bottom_y(after, i), BuildingLayout.floor_bottom_y(before, i), "floor %d's position must not move when a floor is appended above it" % i)


func test_floor_bottom_y_of_reception_sits_on_the_plinth() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	assert_eq(BuildingLayout.floor_bottom_y(floors, 0), -BuildingLayout.PLINTH_HEIGHT)


func test_floor_bottom_y_one_past_the_last_floor_is_the_roof_cap_seat() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)
	var bounds := BuildingLayout.fit_all_bounds(floors)

	var roof_bottom := BuildingLayout.floor_bottom_y(floors, floors.size())

	assert_eq(roof_bottom - BuildingLayout.ROOF_HEIGHT, bounds.position.y, "the roof cap should sit flush against the fit-all bounds' top edge")
