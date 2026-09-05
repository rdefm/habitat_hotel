extends GutTest

## Characterizes ticket 06's extension of sim/building_layout.gd: the
## character-slot resolver (resolve_character_sprite(), Manny's alias, the
## open naming convention every Species/Staffer gets for free) and the
## four single-frame interface resolvers (Tag icons, mood faces, Station
## props, HUD pills). Same shape as tests/test_anchor_registry.gd --
## literal ids and hand-injected probes, no autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


## --- resolve_character_sprite(): Manny's alias ---

func test_manny_walk_resolves_to_his_real_sheet() -> void:
	var sprite := BuildingLayout.resolve_character_sprite("staffer", "manny", "walk")

	assert_eq(sprite["kind"], "sprite")
	assert_eq(sprite["file"], "res://assets/Manny-walk.png")
	assert_eq(sprite["frame_width"], 256.0)
	assert_eq(sprite["frame_height"], 256.0)
	assert_eq(sprite["size"], Vector2(BuildingLayout.CHARACTER_FRAME_SIZE, BuildingLayout.CHARACTER_FRAME_SIZE), "Manny's on-screen footprint matches every other character's, even though his source frames are larger")


func test_manny_working_resolves_to_his_sweeping_sheet() -> void:
	var sprite := BuildingLayout.resolve_character_sprite("staffer", "manny", "working")

	assert_eq(sprite["kind"], "sprite")
	assert_eq(sprite["file"], "res://assets/Manny-sweeping.png")


func test_manny_idle_has_no_alias_and_falls_back_to_a_placeholder() -> void:
	## Manny has no idle sheet -- proves the alias table and the fallback
	## share one resolver rather than Manny being special-cased end to end.
	var sprite := BuildingLayout.resolve_character_sprite("staffer", "manny", "idle")

	assert_eq(sprite["kind"], "placeholder")
	assert_eq(sprite["label"], "MAN")


func test_the_alias_table_takes_priority_over_the_naming_convention() -> void:
	## manny_walk.png at the conventional path is never probed for --
	## if it were, an injected probe claiming it exists would wrongly win.
	var probe := func(_path: String):
		return Vector2(999, 999)

	var sprite := BuildingLayout.resolve_character_sprite("staffer", "manny", "walk", probe)

	assert_eq(sprite["file"], "res://assets/Manny-walk.png")
	assert_eq(sprite["frame_width"], 256.0, "the alias's own frame size, not whatever the (never-consulted) probe implies")


## --- resolve_character_sprite(): the open naming convention every other character gets for free ---

func test_a_species_whose_conventional_sheet_exists_resolves_to_a_sprite() -> void:
	var probe := func(path: String):
		return Vector2(512, 64) if path == "res://assets/characters/guests/capybara_walk.png" else null

	var sprite := BuildingLayout.resolve_character_sprite("guest", "capybara", "walk", probe)

	assert_eq(sprite["kind"], "sprite")
	assert_eq(sprite["file"], "res://assets/characters/guests/capybara_walk.png")
	assert_eq(sprite["frame_width"], BuildingLayout.CHARACTER_FRAME_SIZE, "convention sheets are cut at the fixed contract frame size, not read off the file")


func test_a_staffer_whose_conventional_sheet_exists_resolves_to_a_sprite() -> void:
	var probe := func(path: String):
		return Vector2(64, 64) if path == "res://assets/characters/staffers/shelly_idle.png" else null

	var sprite := BuildingLayout.resolve_character_sprite("staffer", "shelly", "idle", probe)

	assert_eq(sprite["kind"], "sprite")
	assert_eq(sprite["file"], "res://assets/characters/staffers/shelly_idle.png")


func test_a_species_with_no_sheet_anywhere_falls_back_to_a_tinted_labelled_placeholder() -> void:
	var probe := func(_path: String):
		return null

	var sprite := BuildingLayout.resolve_character_sprite("guest", "pigeon", "idle", probe)

	assert_eq(sprite["kind"], "placeholder")
	assert_eq(sprite["label"], "PIG")
	assert_eq(sprite["size"], Vector2(BuildingLayout.CHARACTER_FRAME_SIZE, BuildingLayout.CHARACTER_FRAME_SIZE))


func test_every_species_falls_back_cleanly_with_no_probe_touching_the_real_filesystem() -> void:
	## Proof the fallback holds across the whole current roster, not just
	## one hand-picked id -- real filesystem probe, no such files exist yet.
	var species_ids := ["pigeon", "capybara", "tortoise", "penguin", "flamingo", "bat", "polar_bear", "snow_leopard"]
	for species_id in species_ids:
		for state in BuildingLayout.CHARACTER_STATES["guest"]:
			var sprite := BuildingLayout.resolve_character_sprite("guest", species_id, state)
			assert_eq(sprite["kind"], "placeholder", "%s/%s should still be on the fallback" % [species_id, state])


## --- Placeholder tint/label helpers ---

func test_placeholder_tint_is_deterministic_for_the_same_id() -> void:
	var first := BuildingLayout.placeholder_tint_for_id("flamingo")
	var second := BuildingLayout.placeholder_tint_for_id("flamingo")

	assert_eq(first, second)


func test_placeholder_tints_differ_across_the_current_species_roster() -> void:
	var species_ids := ["pigeon", "capybara", "tortoise", "penguin", "flamingo", "bat", "polar_bear", "snow_leopard"]
	var seen: Dictionary = {}
	for species_id in species_ids:
		var tint := BuildingLayout.placeholder_tint_for_id(species_id)
		assert_false(seen.values().has(tint), "%s's tint collided with an earlier species'" % species_id)
		seen[species_id] = tint


func test_placeholder_label_is_a_short_uppercase_abbreviation() -> void:
	assert_eq(BuildingLayout.placeholder_label_for_id("polar_bear"), "POL")
	assert_eq(BuildingLayout.placeholder_label_for_id("bat"), "BAT")


## --- Animation states named per kind ---

func test_guest_states_are_idle_walk_sleeping() -> void:
	assert_eq(BuildingLayout.CHARACTER_STATES["guest"], ["idle", "walk", "sleeping"])


func test_staffer_states_are_idle_walk_working() -> void:
	assert_eq(BuildingLayout.CHARACTER_STATES["staffer"], ["idle", "walk", "working"])


## --- Tag icons, mood faces, Station props, HUD pills ---

func test_tag_icon_falls_back_to_a_placeholder_when_missing() -> void:
	var icon := BuildingLayout.resolve_tag_icon("warm", func(_p): return false)

	assert_eq(icon["kind"], "placeholder")
	assert_eq(icon["size"], Vector2(BuildingLayout.TAG_ICON_SIZE, BuildingLayout.TAG_ICON_SIZE))
	assert_eq(icon["label"], "WAR")


func test_tag_icon_resolves_to_a_sprite_when_its_conventional_file_exists() -> void:
	var icon := BuildingLayout.resolve_tag_icon("quiet", func(path): return path == "res://assets/tags/quiet.png")

	assert_eq(icon["kind"], "sprite")
	assert_eq(icon["file"], "res://assets/tags/quiet.png")


func test_every_tag_falls_back_cleanly_against_the_real_filesystem() -> void:
	for tag_id in ["cold", "warm", "water", "dry", "high_perch", "spacious", "dark", "quiet"]:
		var icon := BuildingLayout.resolve_tag_icon(tag_id)
		assert_eq(icon["kind"], "placeholder", "%s should still be on the fallback" % tag_id)


func test_mood_face_uses_patience_states_tier_vocabulary() -> void:
	for tier in ["calm", "impatient", "huffy"]:
		var face := BuildingLayout.resolve_mood_face(tier, func(_p): return false)
		assert_eq(face["kind"], "placeholder")
		assert_eq(face["size"], Vector2(BuildingLayout.MOOD_FACE_SIZE, BuildingLayout.MOOD_FACE_SIZE))


func test_station_prop_falls_back_for_every_real_station_id() -> void:
	for station_id in ["reception", "housekeeping", "kitchen"]:
		var prop := BuildingLayout.resolve_station_prop(station_id, func(_p): return false)
		assert_eq(prop["kind"], "placeholder")
		assert_eq(prop["size"], Vector2(BuildingLayout.STATION_PROP_SIZE, BuildingLayout.STATION_PROP_SIZE))


func test_hud_pill_falls_back_at_its_own_non_square_footprint() -> void:
	var pill := BuildingLayout.resolve_hud_pill("cash", func(_p): return false)

	assert_eq(pill["kind"], "placeholder")
	assert_eq(pill["size"], BuildingLayout.HUD_PILL_SIZE)


func test_hud_pill_resolves_to_a_sprite_when_its_conventional_file_exists() -> void:
	var pill := BuildingLayout.resolve_hud_pill("star", func(path): return path == "res://assets/hud/star.png")

	assert_eq(pill["kind"], "sprite")
	assert_eq(pill["file"], "res://assets/hud/star.png")
