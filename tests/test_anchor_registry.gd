extends GutTest

## Characterizes ticket 05's extension of sim/building_layout.gd: the Room
## interior assignment (resolve_room_interior()) and the anchor registry
## (resolve_anchor() plus the indexed lobby_queue/terrace_* resolvers).
## Same shape as tests/test_building_layout.gd -- literal hand-built
## `rooms` dicts and plain `stars` ints, no autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


func _rooms() -> Dictionary:
	var out := {}
	out["lagoon_room"] = {"name": "Lagoon Room", "unlock": {"star": 1}}
	out["ice_grotto"] = {"name": "Ice Grotto", "unlock": {"star": 1}}
	out["roost_loft"] = {"name": "Roost Loft", "unlock": {"star": 1}}
	out["cozy_nook"] = {"name": "Cozy Nook", "unlock": {"star": 1}}
	out["cavern_suite"] = {"name": "Cavern Suite", "unlock": {"star": 1}}
	out["tundra_hall"] = {"name": "Tundra Hall", "unlock": {"star": 1}}
	out["mystery_room"] = {"name": "Mystery Room", "unlock": {"star": 1}}
	return out


## --- resolve_room_interior(): the three painted types ---

func test_lagoon_room_resolves_to_the_jungle_painting() -> void:
	var interior := BuildingLayout.resolve_room_interior("lagoon_room", "Lagoon Room")

	assert_eq(interior["kind"], "painted")
	assert_eq(interior["file"], "room_interior_jungle.png")


func test_ice_grotto_resolves_to_the_ice_painting_at_its_own_height() -> void:
	var interior := BuildingLayout.resolve_room_interior("ice_grotto", "Ice Grotto")

	assert_eq(interior["kind"], "painted")
	assert_eq(interior["file"], "room_interior_ice.png")
	assert_eq(interior["height"], 131.0, "ice_grotto's painted band is shorter than the generic tiled floor height")


func test_roost_loft_resolves_to_the_bamboo_painting_at_its_own_height() -> void:
	var interior := BuildingLayout.resolve_room_interior("roost_loft", "Roost Loft")

	assert_eq(interior["kind"], "painted")
	assert_eq(interior["file"], "room_interior_bamboo.png")
	assert_eq(interior["height"], 158.0)


## --- resolve_room_interior(): the fallback (three unpainted types, plus anything unknown) ---

func test_unpainted_room_type_falls_back_to_a_tinted_labelled_placeholder() -> void:
	var interior := BuildingLayout.resolve_room_interior("cozy_nook", "Cozy Nook")

	assert_eq(interior["kind"], "placeholder")
	assert_eq(interior["label"], "Cozy Nook")
	assert_eq(interior["height"], BuildingLayout.ROOM_FLOOR_HEIGHT, "the fallback's footprint matches the tiled generic floor, same as ticket 04's placeholder")


func test_the_three_unpainted_room_types_get_distinct_tints() -> void:
	var cozy: Color = BuildingLayout.resolve_room_interior("cozy_nook", "Cozy Nook")["tint"]
	var cavern: Color = BuildingLayout.resolve_room_interior("cavern_suite", "Cavern Suite")["tint"]
	var tundra: Color = BuildingLayout.resolve_room_interior("tundra_hall", "Tundra Hall")["tint"]

	assert_ne(cozy, cavern)
	assert_ne(cavern, tundra)
	assert_ne(cozy, tundra)


func test_a_room_type_with_no_assigned_slot_at_all_still_falls_back_cleanly() -> void:
	## Proves the fallback rule holds for a hypothetical future Room type
	## this ticket never heard of, not just the three named ones -- the
	## contract's "missing asset renders a placeholder" promise, exercised
	## against the real filesystem (no such file exists) rather than a
	## mocked probe.
	var interior := BuildingLayout.resolve_room_interior("mystery_room", "Mystery Room")

	assert_eq(interior["kind"], "placeholder")
	assert_eq(interior["tint"], BuildingLayout.DEFAULT_PLACEHOLDER_TINT)
	assert_eq(interior["label"], "Mystery Room")


## --- resolve_room_interior(): the naming-convention slot every OTHER Room type gets for free ---
##
## The three ROOM_TYPE_INTERIOR_FILE aliases aside, ANY Room type id
## resolves painted the moment "room_interior_<id>.png" exists under
## SHELL_DIR -- no mapping entry needed. `probe_fn` stands in for the real
## filesystem check so these run hermetically; floors() and every other
## caller use the real default (_probe_shell_file_height()) instead.

func test_a_room_type_whose_conventional_file_exists_resolves_to_painted() -> void:
	var probe := func(filename: String):
		return 200.0 if filename == "room_interior_savanna_den.png" else null

	var interior := BuildingLayout.resolve_room_interior("savanna_den", "Savanna Den", probe)

	assert_eq(interior["kind"], "painted")
	assert_eq(interior["file"], "room_interior_savanna_den.png")
	assert_eq(interior["height"], 200.0, "the convention slot uses the dropped-in file's own real height, not a fixed constant")


func test_a_room_type_whose_conventional_file_is_absent_falls_back_to_placeholder() -> void:
	var probe := func(_filename: String):
		return null

	var interior := BuildingLayout.resolve_room_interior("savanna_den", "Savanna Den", probe)

	assert_eq(interior["kind"], "placeholder")


func test_the_alias_table_takes_priority_over_the_naming_convention() -> void:
	## lagoon_room's real file (room_interior_jungle.png) doesn't match the
	## "room_interior_lagoon_room.png" convention -- if the probe were ever
	## consulted for an aliased type, this would wrongly fall back. Proves
	## resolve_room_interior() checks ROOM_TYPE_INTERIOR_FILE first.
	var probe := func(_filename: String):
		return null

	var interior := BuildingLayout.resolve_room_interior("lagoon_room", "Lagoon Room", probe)

	assert_eq(interior["kind"], "painted")
	assert_eq(interior["file"], "room_interior_jungle.png")


## --- floors() integration: band_variant and height follow resolve_room_interior() ---

func test_floors_marks_painted_room_types_as_full_band_variant() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)
	var by_id := {}
	for f in floors:
		if f["kind"] == "room":
			by_id[f["room_type_id"]] = f

	assert_eq(by_id["lagoon_room"]["band_variant"], "full")
	assert_eq(by_id["lagoon_room"]["height"], BuildingLayout.ROOM_FLOOR_HEIGHT)
	assert_eq(by_id["ice_grotto"]["band_variant"], "full")
	assert_eq(by_id["ice_grotto"]["height"], 131.0)
	assert_eq(by_id["roost_loft"]["band_variant"], "full")
	assert_eq(by_id["roost_loft"]["height"], 158.0)


func test_floors_marks_unpainted_room_types_as_tiled_band_variant() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)
	var by_id := {}
	for f in floors:
		if f["kind"] == "room":
			by_id[f["room_type_id"]] = f

	assert_eq(by_id["cozy_nook"]["band_variant"], "tiled")
	assert_eq(by_id["cozy_nook"]["height"], BuildingLayout.ROOM_FLOOR_HEIGHT)
	assert_eq(by_id["cavern_suite"]["band_variant"], "tiled")
	assert_eq(by_id["tundra_hall"]["band_variant"], "tiled")


func test_floors_carries_the_resolved_interior_on_every_room_entry() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)
	for f in floors:
		if f["kind"] == "room":
			assert_true(f.has("interior"), "room floor entry should carry its resolved interior: %s" % f["room_type_id"])
			assert_eq(f["interior"]["kind"] in ["painted", "placeholder"], true)


## --- Anchor registry: named anchors (resolve_anchor) ---

func test_elevator_door_sits_at_the_same_x_on_every_floor_kind() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	var reception_door: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "elevator_door")
	var terrace_door: Vector2 = BuildingLayout.resolve_anchor(floors, 1, "elevator_door")
	var room_door: Vector2 = BuildingLayout.resolve_anchor(floors, 2, "elevator_door")

	assert_eq(reception_door.x, BuildingLayout.SHAFT_CENTER_X)
	assert_eq(terrace_door.x, BuildingLayout.SHAFT_CENTER_X)
	assert_eq(room_door.x, BuildingLayout.SHAFT_CENTER_X)


func test_elevator_door_sits_at_each_floors_own_floor_level() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	var reception_bottom: float = BuildingLayout.floor_bottom_y(floors, 0)
	var reception_door: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "elevator_door")

	assert_eq(reception_door.y, reception_bottom, "the door sits at the floor's own bottom edge (floor level), not the band's top edge")


func test_front_desk_supply_closet_and_staff_nook_are_distinct_reception_positions() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	var desk: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "front_desk")
	var closet: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "supply_closet")
	var nook: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "staff_nook")

	assert_ne(desk, closet)
	assert_ne(closet, nook)
	assert_ne(desk, nook)


func test_reception_only_anchors_do_not_resolve_on_a_room_floor() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	assert_null(BuildingLayout.resolve_anchor(floors, 2, "front_desk"), "front_desk belongs to Reception's band, not a Room floor")
	assert_null(BuildingLayout.resolve_anchor(floors, 0, "bay_left"), "bay_left belongs to a Room floor's band, not Reception")


func test_bay_left_and_bay_right_are_equal_width_rects_that_tile_the_interior() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)
	var room_index := 2 # cozy_nook, star 1, first Room floor above the Terrace

	var bay_left: Rect2 = BuildingLayout.resolve_anchor(floors, room_index, "bay_left")
	var bay_right: Rect2 = BuildingLayout.resolve_anchor(floors, room_index, "bay_right")

	assert_eq(bay_left.size, bay_right.size)
	assert_eq(bay_left.position.x + bay_left.size.x, bay_right.position.x, "the two bays should meet with no gap")
	assert_eq(bay_left.size.y, float(floors[room_index]["height"]), "a bay spans its own floor's full height")


func test_bay_rects_move_with_a_taller_or_shorter_painted_floor() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)
	var by_id := {}
	for i in range(floors.size()):
		if floors[i]["kind"] == "room":
			by_id[floors[i]["room_type_id"]] = i

	var ice_bay: Rect2 = BuildingLayout.resolve_anchor(floors, by_id["ice_grotto"], "bay_left")
	assert_eq(ice_bay.size.y, 131.0, "ice_grotto's shorter painted band should shrink its bay rects to match")


## --- Anchor registry: indexed anchors (lobby queue, terrace diners/queue) ---

func test_lobby_queue_points_advance_along_x_at_a_fixed_spacing() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	var p0: Vector2 = BuildingLayout.resolve_lobby_queue_point(floors, 0, 0)
	var p1: Vector2 = BuildingLayout.resolve_lobby_queue_point(floors, 0, 1)

	assert_eq(p1.y, p0.y, "the queue is a line -- constant y")
	assert_eq(p1.x - p0.x, BuildingLayout.QUEUE_SPACING)


func test_terrace_entrance_queue_is_independent_of_the_lobby_queue() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	var lobby: Vector2 = BuildingLayout.resolve_lobby_queue_point(floors, 0, 0)
	var terrace: Vector2 = BuildingLayout.resolve_terrace_entrance_queue_point(floors, 1, 0)

	assert_ne(lobby, terrace)


func test_diner_spots_form_a_two_column_grid() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)

	var spot0: Vector2 = BuildingLayout.resolve_terrace_diner_spot(floors, 1, 0)
	var spot1: Vector2 = BuildingLayout.resolve_terrace_diner_spot(floors, 1, 1)
	var spot2: Vector2 = BuildingLayout.resolve_terrace_diner_spot(floors, 1, 2)

	assert_eq(spot1.y, spot0.y, "spots 0 and 1 are the same row")
	assert_ne(spot1.x, spot0.x, "spots 0 and 1 are different columns")
	assert_eq(spot2.x, spot0.x, "spot 2 wraps to the next row, same column as spot 0")
	assert_ne(spot2.y, spot0.y)


func test_indexed_anchors_translate_by_the_floors_own_top_y() -> void:
	var floors := BuildingLayout.floors(_rooms(), 1)
	var terrace_top_y: float = BuildingLayout.floor_bottom_y(floors, 1) - float(floors[1]["height"])

	var spot: Vector2 = BuildingLayout.resolve_terrace_diner_spot(floors, 1, 0)

	assert_eq(spot.y - terrace_top_y, BuildingLayout.TERRACE_DINER_GRID_ORIGIN.y, "the world position should be the local anchor offset by the floor's own top_y")
