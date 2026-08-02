class_name DataLoader
extends RefCounted

## Parses res://data/*.json into typed dictionaries keyed by id, validating
## required fields and tag references. Malformed entries are logged via
## push_error() and skipped rather than crashing the loader.

const DATA_DIR := "res://data/"

const SPECIES_REQUIRED_FIELDS := [
	"id", "name", "tier", "needs", "likes", "budget",
	"party_size", "base_stay_days", "amenity_prefs", "flavor_lines",
]

const ROOM_REQUIRED_FIELDS := [
	"id", "name", "tags", "build_cost", "upkeep_per_day",
	"base_rate", "capacity", "unlock", "max_instances",
]

const TRAIT_REQUIRED_FIELDS := ["id", "name", "description"]


static func load_all() -> Dictionary:
	var tags := load_tags()
	var species := load_species(tags)
	var rooms := load_rooms(tags)
	var traits := load_traits()
	var seasons := load_seasons(tags)
	var balance := load_balance()
	var starting_hotel := load_starting_hotel(rooms)
	var names := load_names(species)
	return {
		"tags": tags,
		"species": species,
		"rooms": rooms,
		"traits": traits,
		"seasons": seasons,
		"balance": balance,
		"starting_hotel": starting_hotel,
		"names": names,
	}


static func _read_json(filename: String) -> Variant:
	var path := DATA_DIR + filename
	if not FileAccess.file_exists(path):
		push_error("[DataLoader] Missing data file: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DataLoader] Could not open data file: %s (error %d)" % [path, FileAccess.get_open_error()])
		return null
	var text := file.get_as_text()
	var json := JSON.new()
	var parse_error := json.parse(text)
	if parse_error != OK:
		push_error("[DataLoader] Failed to parse %s at line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


static func load_tags() -> Dictionary:
	var raw: Variant = _read_json("tags.json")
	var tags := {}
	if raw == null:
		return tags
	if not (raw is Array):
		push_error("[DataLoader] tags.json must be a JSON array of strings")
		return tags
	for entry in raw:
		if typeof(entry) != TYPE_STRING:
			push_error("[DataLoader] tags.json entry is not a string: %s" % str(entry))
			continue
		tags[entry] = true
	return tags


static func load_species(valid_tags: Dictionary) -> Dictionary:
	var raw: Variant = _read_json("species.json")
	var out := {}
	if raw == null:
		return out
	if not (raw is Array):
		push_error("[DataLoader] species.json must be a JSON array of objects")
		return out
	for entry in raw:
		if entry is Dictionary and _validate_species(entry, valid_tags):
			out[entry["id"]] = entry
	return out


static func _validate_species(entry: Dictionary, valid_tags: Dictionary) -> bool:
	for field in SPECIES_REQUIRED_FIELDS:
		if not entry.has(field):
			push_error("[DataLoader] species entry missing '%s': %s" % [field, JSON.stringify(entry)])
			return false
	for tag in entry["needs"]:
		if not valid_tags.has(tag):
			push_error("[DataLoader] species '%s' needs unknown tag '%s'" % [entry["id"], tag])
			return false
	for tag in entry["likes"]:
		if not valid_tags.has(tag):
			push_error("[DataLoader] species '%s' likes unknown tag '%s'" % [entry["id"], tag])
			return false
	return true


static func load_rooms(valid_tags: Dictionary) -> Dictionary:
	var raw: Variant = _read_json("rooms.json")
	var out := {}
	if raw == null:
		return out
	if not (raw is Array):
		push_error("[DataLoader] rooms.json must be a JSON array of objects")
		return out
	for entry in raw:
		if entry is Dictionary and _validate_room(entry, valid_tags):
			out[entry["id"]] = entry
	return out


static func _validate_room(entry: Dictionary, valid_tags: Dictionary) -> bool:
	for field in ROOM_REQUIRED_FIELDS:
		if not entry.has(field):
			push_error("[DataLoader] room entry missing '%s': %s" % [field, JSON.stringify(entry)])
			return false
	for tag in entry["tags"]:
		if not valid_tags.has(tag):
			push_error("[DataLoader] room '%s' has unknown tag '%s'" % [entry["id"], tag])
			return false
	if not (entry["unlock"] is Dictionary and entry["unlock"].has("star")):
		push_error("[DataLoader] room '%s' unlock must be an object with a 'star' field" % entry["id"])
		return false
	for upgrade in entry.get("upgrades", []):
		if not _validate_room_upgrade(entry["id"], upgrade, valid_tags):
			return false
	return true


const ROOM_UPGRADE_EFFECT_FIELDS := ["adds_tag", "upkeep_delta", "capacity_delta", "satisfaction_bonus"]


## Upgrades are per-instance modifiers, not per-instance rooms: id/name/
## description/costs are required; at least one effect field (adds_tag,
## upkeep_delta, capacity_delta, satisfaction_bonus) must be present, but
## all are individually optional so an upgrade can mix and match effects.
static func _validate_room_upgrade(room_id: String, upgrade: Variant, valid_tags: Dictionary) -> bool:
	if not (upgrade is Dictionary):
		push_error("[DataLoader] room '%s' has a non-object upgrade entry" % room_id)
		return false
	for field in ["id", "name", "description", "cost_hearts", "cost_cash"]:
		if not upgrade.has(field):
			push_error("[DataLoader] room '%s' upgrade missing '%s': %s" % [room_id, field, JSON.stringify(upgrade)])
			return false
	if upgrade.has("adds_tag") and not valid_tags.has(upgrade["adds_tag"]):
		push_error("[DataLoader] room '%s' upgrade '%s' adds unknown tag '%s'" % [room_id, upgrade["id"], upgrade["adds_tag"]])
		return false
	var has_effect := false
	for field in ROOM_UPGRADE_EFFECT_FIELDS:
		if upgrade.has(field):
			has_effect = true
			break
	if not has_effect:
		push_error("[DataLoader] room '%s' upgrade '%s' has no effect fields (%s)" % [room_id, upgrade["id"], ROOM_UPGRADE_EFFECT_FIELDS])
		return false
	return true


static func load_traits() -> Dictionary:
	var raw: Variant = _read_json("traits.json")
	var out := {}
	if raw == null:
		return out
	if not (raw is Array):
		push_error("[DataLoader] traits.json must be a JSON array of objects")
		return out
	for entry in raw:
		if entry is Dictionary and _validate_trait(entry):
			out[entry["id"]] = entry
	return out


static func _validate_trait(entry: Dictionary) -> bool:
	for field in TRAIT_REQUIRED_FIELDS:
		if not entry.has(field):
			push_error("[DataLoader] trait entry missing '%s': %s" % [field, JSON.stringify(entry)])
			return false
	return true


static func load_seasons(valid_tags: Dictionary) -> Dictionary:
	var raw: Variant = _read_json("seasons.json")
	var out := {}
	if raw == null:
		return out
	if not (raw is Array):
		push_error("[DataLoader] seasons.json must be a JSON array of objects")
		return out
	for entry in raw:
		if entry is Dictionary and _validate_season(entry, valid_tags):
			out[entry["id"]] = entry
	return out


static func _validate_season(entry: Dictionary, valid_tags: Dictionary) -> bool:
	for field in ["id", "tag_weights"]:
		if not entry.has(field):
			push_error("[DataLoader] season entry missing '%s': %s" % [field, JSON.stringify(entry)])
			return false
	if not (entry["tag_weights"] is Dictionary):
		push_error("[DataLoader] season '%s' tag_weights must be an object" % entry["id"])
		return false
	for tag in entry["tag_weights"].keys():
		if not valid_tags.has(tag):
			push_error("[DataLoader] season '%s' has unknown tag '%s' in tag_weights" % [entry["id"], tag])
			return false
	return true


const BALANCE_REQUIRED_SECTIONS := {
	"satisfaction": ["base", "missing_need_penalty", "like_bonus", "care_per_night", "care_cap", "amenity_bonus", "min", "max"],
	"review": ["positive_threshold", "negative_threshold", "reputation_delta_positive", "reputation_delta_negative", "reputation_delta_walkaway"],
	"hearts": ["threshold", "step", "max"],
	"demand": ["base_min", "base_max", "reputation_weight_min", "reputation_weight_max"],
	"costs": ["staff_wage_per_day"],
	"pricing": ["min_multiplier", "max_multiplier", "step", "default_multiplier", "tolerance"],
}


static func load_balance() -> Dictionary:
	var raw: Variant = _read_json("balance.json")
	if raw == null:
		return {}
	if not (raw is Dictionary):
		push_error("[DataLoader] balance.json must be a JSON object")
		return {}
	for section in BALANCE_REQUIRED_SECTIONS.keys():
		if not raw.has(section) or not (raw[section] is Dictionary):
			push_error("[DataLoader] balance.json missing section '%s'" % section)
			continue
		for field in BALANCE_REQUIRED_SECTIONS[section]:
			if not raw[section].has(field):
				push_error("[DataLoader] balance.json section '%s' missing field '%s'" % [section, field])
	return raw


static func load_starting_hotel(valid_rooms: Dictionary) -> Array:
	var raw: Variant = _read_json("starting_hotel.json")
	var out := []
	if raw == null:
		return out
	if not (raw is Array):
		push_error("[DataLoader] starting_hotel.json must be a JSON array of objects")
		return out
	for entry in raw:
		if entry is Dictionary and _validate_starting_room(entry, valid_rooms):
			out.append(entry)
	return out


static func _validate_starting_room(entry: Dictionary, valid_rooms: Dictionary) -> bool:
	if not entry.has("room_type_id"):
		push_error("[DataLoader] starting_hotel entry missing 'room_type_id': %s" % JSON.stringify(entry))
		return false
	if not valid_rooms.has(entry["room_type_id"]):
		push_error("[DataLoader] starting_hotel references unknown room type '%s'" % entry["room_type_id"])
		return false
	return true


## Guest name pools: a "general" list any species can draw from, plus
## optional per-species lists. DemandGenerator picks 50/50 between the
## general pool and the arriving guest's species pool (falling back to
## general if that species has no list of its own).
static func load_names(valid_species: Dictionary) -> Dictionary:
	var out := {"general": [], "species": {}}
	var raw: Variant = _read_json("names.json")
	if raw == null:
		return out
	if not (raw is Dictionary):
		push_error("[DataLoader] names.json must be a JSON object")
		return out

	var general: Variant = raw.get("general", [])
	if not (general is Array):
		push_error("[DataLoader] names.json 'general' must be an array of strings")
	else:
		out["general"] = _clean_name_list(general, "general")
	if out["general"].is_empty():
		push_error("[DataLoader] names.json 'general' must contain at least one name")

	var species_lists: Variant = raw.get("species", {})
	if not (species_lists is Dictionary):
		push_error("[DataLoader] names.json 'species' must be an object of species_id -> array")
		return out
	for species_id in species_lists.keys():
		if not valid_species.has(species_id):
			push_error("[DataLoader] names.json 'species' references unknown species '%s'" % species_id)
			continue
		var list: Variant = species_lists[species_id]
		if not (list is Array):
			push_error("[DataLoader] names.json 'species.%s' must be an array of strings" % species_id)
			continue
		out["species"][species_id] = _clean_name_list(list, species_id)
	return out


static func _clean_name_list(raw_list: Array, context: String) -> Array:
	var out := []
	for entry in raw_list:
		if typeof(entry) != TYPE_STRING or entry.is_empty():
			push_error("[DataLoader] names.json '%s' has a non-string/empty entry: %s" % [context, str(entry)])
			continue
		out.append(entry)
	return out
