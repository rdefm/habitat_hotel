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


func test_manny_idle_resolves_to_his_real_still_alias() -> void:
	var sprite := BuildingLayout.resolve_character_sprite("staffer", "manny", "idle")

	assert_eq(sprite["kind"], "sprite")
	assert_eq(sprite["file"], "res://assets/manny.png")
	assert_eq(sprite["frame_width"], 76.0)
	assert_eq(sprite["frame_height"], 76.0)


func test_mannys_walk_and_working_sheets_carry_their_measured_foot_padding() -> void:
	## Both sheets' actual art sits well short of their 256px frame's bottom
	## edge -- ui/character_sprite.gd uses this to nudge the sprite down so
	## Manny stands on the anchor instead of floating above it.
	var walk := BuildingLayout.resolve_character_sprite("staffer", "manny", "walk")
	var working := BuildingLayout.resolve_character_sprite("staffer", "manny", "working")

	assert_eq(walk["foot_padding"], 37.0)
	assert_eq(working["foot_padding"], 31.0)


func test_mannys_idle_still_has_no_foot_padding_correction() -> void:
	## His idle still is already flush with its frame's bottom edge, unlike
	## the walk/working sheets above.
	var sprite := BuildingLayout.resolve_character_sprite("staffer", "manny", "idle")

	assert_eq(sprite["foot_padding"], 0.0)


func test_manny_has_one_aliased_ambient_idle_clip() -> void:
	var clips := BuildingLayout.resolve_character_idle_clips("staffer", "manny")

	assert_eq(clips.size(), 1)
	assert_eq(clips[0]["file"], "res://assets/manny-idle.png")
	assert_eq(clips[0]["frame_width"], 82.0)
	assert_eq(clips[0]["frame_height"], 82.0)


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


func test_species_with_no_real_art_still_fall_back_cleanly_against_the_real_filesystem() -> void:
	## Proof the fallback still holds for the rest of the roster -- real
	## filesystem probe, no such files exist for these five.
	var species_ids := ["capybara", "flamingo", "bat", "polar_bear", "snow_leopard"]
	for species_id in species_ids:
		for state in BuildingLayout.CHARACTER_STATES["guest"]:
			var sprite := BuildingLayout.resolve_character_sprite("guest", species_id, state)
			assert_eq(sprite["kind"], "placeholder", "%s/%s should still be on the fallback" % [species_id, state])


func test_pigeon_and_penguin_resolve_their_real_idle_and_walk_art() -> void:
	## These two are cut to the convention -- real filesystem probe,
	## proving the open convention slot works with no injected probe.
	for species_id in ["pigeon", "penguin"]:
		for state in ["idle", "walk"]:
			var sprite := BuildingLayout.resolve_character_sprite("guest", species_id, state)
			assert_eq(sprite["kind"], "sprite", "%s/%s should now resolve to real art" % [species_id, state])
		var sleeping := BuildingLayout.resolve_character_sprite("guest", species_id, "sleeping")
		assert_eq(sleeping["kind"], "placeholder", "%s has no sleeping art yet" % species_id)


func test_shelly_resolves_her_real_idle_and_walk_art_against_the_real_filesystem() -> void:
	## Shelly (Staffer) carries the tortoise-themed art at her own
	## convention slot -- moved here from the tortoise Species' guest slot,
	## which now falls back like any other unpainted Species (see the
	## fallback test below).
	for state in ["idle", "walk"]:
		var sprite := BuildingLayout.resolve_character_sprite("staffer", "shelly", state)
		assert_eq(sprite["kind"], "sprite", "shelly/%s should resolve to real art" % state)
		assert_eq(sprite["foot_padding"], 5.0, "shelly/%s's art sits a little short of its own frame's bottom edge" % state)
	var working := BuildingLayout.resolve_character_sprite("staffer", "shelly", "working")
	assert_eq(working["kind"], "placeholder", "shelly has no working art")


func test_tortoise_species_now_falls_back_since_its_art_moved_to_shelly() -> void:
	for state in BuildingLayout.CHARACTER_STATES["guest"]:
		var sprite := BuildingLayout.resolve_character_sprite("guest", "tortoise", state)
		assert_eq(sprite["kind"], "placeholder", "tortoise/%s should be on the fallback now that its art belongs to Shelly" % state)


## --- resolve_character_idle_clips(): ambient idle animation ---

func test_a_species_with_two_numbered_idle_clips_resolves_both_in_order() -> void:
	var clips := BuildingLayout.resolve_character_idle_clips("guest", "pigeon")

	assert_eq(clips.size(), 2)
	assert_eq(clips[0]["file"], "res://assets/characters/guests/pigeon_idle_1.png")
	assert_eq(clips[1]["file"], "res://assets/characters/guests/pigeon_idle_2.png")


func test_a_staffer_with_one_numbered_idle_clip_resolves_just_that_one() -> void:
	## Shelly's tortoise-themed art carries the one idle clip that used to
	## sit on the tortoise Species' guest slot.
	var clips := BuildingLayout.resolve_character_idle_clips("staffer", "shelly")

	assert_eq(clips.size(), 1)
	assert_eq(clips[0]["file"], "res://assets/characters/staffers/shelly_idle_1.png")


func test_tortoise_species_has_no_idle_clips_now_that_its_art_moved_to_shelly() -> void:
	var clips := BuildingLayout.resolve_character_idle_clips("guest", "tortoise")

	assert_true(clips.is_empty())


func test_a_species_with_a_still_and_a_walk_but_no_idle_clip_resolves_none() -> void:
	## Penguin proves a missing clip is a legitimate permanent case, not a
	## gap -- it still has real idle/walk art, just nothing to animate to.
	var clips := BuildingLayout.resolve_character_idle_clips("guest", "penguin")

	assert_true(clips.is_empty())


func test_a_species_with_no_art_at_all_resolves_no_idle_clips() -> void:
	var clips := BuildingLayout.resolve_character_idle_clips("guest", "capybara")

	assert_true(clips.is_empty())


func test_idle_clip_numbering_stops_at_the_first_gap() -> void:
	var probe := func(path: String):
		if path == "res://assets/characters/guests/flamingo_idle_1.png":
			return Vector2(512, 64)
		if path == "res://assets/characters/guests/flamingo_idle_2.png":
			return null
		if path == "res://assets/characters/guests/flamingo_idle_3.png":
			return Vector2(512, 64) # would only be found by a buggy resolver that doesn't stop at the gap
		return null

	var clips := BuildingLayout.resolve_character_idle_clips("guest", "flamingo", probe)

	assert_eq(clips.size(), 1)
	assert_eq(clips[0]["file"], "res://assets/characters/guests/flamingo_idle_1.png")


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


## --- resolve_mood_face_for_patience(): Patience value -> mood face (ticket 10) ---

const PATIENCE_CFG := {"start": 80, "decay_per_tick": 1, "impatient_at": 40, "huffy_at": 15}


func test_a_calm_patience_value_resolves_to_the_calm_mood_face() -> void:
	var face := BuildingLayout.resolve_mood_face_for_patience(80.0, PATIENCE_CFG, func(_p): return false)

	assert_eq(face, BuildingLayout.resolve_mood_face("calm", func(_p): return false))


func test_an_impatient_patience_value_resolves_to_the_impatient_mood_face() -> void:
	var face := BuildingLayout.resolve_mood_face_for_patience(40.0, PATIENCE_CFG, func(_p): return false)

	assert_eq(face, BuildingLayout.resolve_mood_face("impatient", func(_p): return false))


func test_a_huffy_patience_value_resolves_to_the_huffy_mood_face() -> void:
	var face := BuildingLayout.resolve_mood_face_for_patience(0.0, PATIENCE_CFG, func(_p): return false)

	assert_eq(face, BuildingLayout.resolve_mood_face("huffy", func(_p): return false))


func test_mood_face_for_patience_sours_continuously_as_patience_decays() -> void:
	## Same value, decaying tick by tick, crosses all three tiers -- the
	## point of a continuous mood face rather than a threshold alert.
	var calm := BuildingLayout.resolve_mood_face_for_patience(41.0, PATIENCE_CFG, func(_p): return false)
	var impatient := BuildingLayout.resolve_mood_face_for_patience(16.0, PATIENCE_CFG, func(_p): return false)
	var huffy := BuildingLayout.resolve_mood_face_for_patience(15.0, PATIENCE_CFG, func(_p): return false)

	assert_eq(calm, BuildingLayout.resolve_mood_face("calm", func(_p): return false))
	assert_eq(impatient, BuildingLayout.resolve_mood_face("impatient", func(_p): return false))
	assert_eq(huffy, BuildingLayout.resolve_mood_face("huffy", func(_p): return false))


func test_mood_face_for_patience_uses_the_dining_walkin_patience_thresholds_when_given_that_config() -> void:
	## Same resolver, the Terrace's own (different) start/threshold values --
	## proves it's the caller's patience_cfg, not a hardcoded Reception one.
	var dining_cfg := {"start": 48, "decay_per_tick": 1, "impatient_at": 24, "huffy_at": 9, "unstaffed_multiplier": 1.6}

	var face := BuildingLayout.resolve_mood_face_for_patience(9.0, dining_cfg, func(_p): return false)

	assert_eq(face, BuildingLayout.resolve_mood_face("huffy", func(_p): return false))


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
