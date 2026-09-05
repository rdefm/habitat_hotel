extends GutTest

## Characterizes ticket 08's extension of sim/building_layout.gd: bay
## mapping (room_bay_states()), per-bay visual state derived from a room
## instance (room_bay_visual_state()), and the door-plate room number
## (room_number()). Same shape as tests/test_station_placement.gd -- plain
## literal values in, no autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


## --- room_bay_states() ---

func test_no_built_rooms_and_build_allowed_gives_one_build_slot_then_an_empty_shell() -> void:
	var bays := BuildingLayout.room_bay_states(0, true)

	assert_eq(bays.size(), 2)
	assert_eq(bays[0]["state"], "build_slot")
	assert_eq(bays[0]["instance_id"], -1)
	assert_eq(bays[1]["state"], "empty")
	assert_eq(bays[1]["instance_id"], -1)


func test_one_built_room_and_build_allowed_fills_bay_zero_and_offers_bay_one_as_a_build_slot() -> void:
	var bays := BuildingLayout.room_bay_states(1, true)

	assert_eq(bays[0]["state"], "built")
	assert_eq(bays[0]["instance_id"], 0)
	assert_eq(bays[1]["state"], "build_slot")
	assert_eq(bays[1]["instance_id"], -1)


func test_two_built_rooms_fills_both_bays_with_no_build_slot_even_if_build_were_allowed() -> void:
	var bays := BuildingLayout.room_bay_states(2, true)

	assert_eq(bays[0]["state"], "built")
	assert_eq(bays[0]["instance_id"], 0)
	assert_eq(bays[1]["state"], "built")
	assert_eq(bays[1]["instance_id"], 1)


func test_no_built_rooms_and_build_not_allowed_gives_two_empty_shells() -> void:
	var bays := BuildingLayout.room_bay_states(0, false)

	assert_eq(bays[0]["state"], "empty")
	assert_eq(bays[1]["state"], "empty")


func test_at_most_one_build_slot_bay_even_with_two_open_bays() -> void:
	var bays := BuildingLayout.room_bay_states(0, true)

	var build_slot_count := 0
	for bay in bays:
		if bay["state"] == "build_slot":
			build_slot_count += 1
	assert_eq(build_slot_count, 1)


## --- room_bay_visual_state() ---

func _room(overrides: Dictionary = {}) -> Dictionary:
	var room := {
		"occupant": null,
		"needs_cleaning": false,
		"upgrades": [],
	}
	for key in overrides.keys():
		room[key] = overrides[key]
	return room


func test_an_unoccupied_room_that_needs_cleaning_is_dirty() -> void:
	var state := BuildingLayout.room_bay_visual_state(_room({"needs_cleaning": true}))

	assert_true(state["dirty"])
	assert_false(state["occupied"])


func test_an_occupied_room_never_shows_dirty_even_if_it_needs_cleaning() -> void:
	var state := BuildingLayout.room_bay_visual_state(_room({"occupant": "party_1", "needs_cleaning": true}))

	assert_true(state["occupied"])
	assert_false(state["dirty"], "an occupied Room's guest is the visible state, not its housekeeping backlog")


func test_a_clean_unoccupied_room_is_not_dirty() -> void:
	var state := BuildingLayout.room_bay_visual_state(_room())

	assert_false(state["dirty"])


func test_purchased_upgrades_pass_through_as_upgrade_ids() -> void:
	var state := BuildingLayout.room_bay_visual_state(_room({"upgrades": ["extra_bedding", "insulated_walls"]}))

	assert_eq(state["upgrade_ids"], ["extra_bedding", "insulated_walls"])


func test_no_upgrades_gives_an_empty_upgrade_id_list() -> void:
	var state := BuildingLayout.room_bay_visual_state(_room())

	assert_eq(state["upgrade_ids"], [])


## --- room_number() ---

func test_room_number_combines_level_and_bay_index() -> void:
	assert_eq(BuildingLayout.room_number(2, 0), 201)
	assert_eq(BuildingLayout.room_number(2, 1), 202)


func test_room_number_scales_with_level() -> void:
	assert_eq(BuildingLayout.room_number(3, 0), 301)
	assert_eq(BuildingLayout.room_number(5, 1), 502)


## --- resolve_mess_overlay() / resolve_upgrade_prop() ---
## Same open-convention-else-placeholder shape as resolve_tag_icon() et al.
## (tests/test_character_contract.gd) -- probe_fn stands in for the
## filesystem so these don't touch it directly.

func test_mess_overlay_falls_back_to_a_placeholder_when_missing() -> void:
	var overlay := BuildingLayout.resolve_mess_overlay(func(_p): return false)

	assert_eq(overlay["kind"], "placeholder")
	assert_eq(overlay["size"], Vector2(BuildingLayout.MESS_OVERLAY_SIZE, BuildingLayout.MESS_OVERLAY_SIZE))


func test_mess_overlay_resolves_to_a_sprite_when_its_conventional_file_exists() -> void:
	var overlay := BuildingLayout.resolve_mess_overlay(func(path): return path == "res://assets/effects/mess.png")

	assert_eq(overlay["kind"], "sprite")
	assert_eq(overlay["file"], "res://assets/effects/mess.png")


func test_mess_overlay_falls_back_cleanly_against_the_real_filesystem() -> void:
	var overlay := BuildingLayout.resolve_mess_overlay()

	assert_eq(overlay["kind"], "placeholder")


func test_upgrade_prop_falls_back_to_a_placeholder_when_missing() -> void:
	var prop := BuildingLayout.resolve_upgrade_prop("extra_bedding", func(_p): return false)

	assert_eq(prop["kind"], "placeholder")
	assert_eq(prop["size"], Vector2(BuildingLayout.UPGRADE_PROP_SIZE, BuildingLayout.UPGRADE_PROP_SIZE))
	assert_eq(prop["label"], "EXT")


func test_upgrade_prop_resolves_to_a_sprite_when_its_conventional_file_exists() -> void:
	var prop := BuildingLayout.resolve_upgrade_prop("soundproofing", func(path): return path == "res://assets/upgrades/soundproofing.png")

	assert_eq(prop["kind"], "sprite")
	assert_eq(prop["file"], "res://assets/upgrades/soundproofing.png")


func test_every_upgrade_id_in_the_current_rooms_catalog_falls_back_cleanly() -> void:
	for room_type_id in GameState.rooms.keys():
		for upgrade in GameState.rooms[room_type_id].get("upgrades", []):
			var prop := BuildingLayout.resolve_upgrade_prop(String(upgrade["id"]))
			assert_eq(prop["kind"], "placeholder", "%s should still be on the fallback" % upgrade["id"])
