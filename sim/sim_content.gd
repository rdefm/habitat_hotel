class_name SimContent
extends RefCounted

## Loads and holds the read-only content tables from data/*.json.
## Pure file IO + parsing -- no Node, no scene tree, safe for headless tests.

var species: Dictionary = {}
var rooms: Dictionary = {}
var balance: Dictionary = {}

static func load_from_dir(data_dir: String) -> SimContent:
	var content := SimContent.new()
	content.species = _load_json(data_dir.path_join("species.json"))
	content.rooms = _load_json(data_dir.path_join("rooms.json"))
	content.balance = _load_json(data_dir.path_join("balance.json"))
	return content

static func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SimContent: could not open %s (error %d)" % [path, FileAccess.get_open_error()])
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("SimContent: failed to parse JSON at %s" % path)
		return {}
	return parsed

func species_ids_at_or_below_tier(max_tier: int) -> Array[String]:
	var out: Array[String] = []
	for id in species.keys():
		if int(species[id]["tier"]) <= max_tier:
			out.append(id)
	return out

func room_type_ids_at_or_below_tier(max_tier: int) -> Array[String]:
	var out: Array[String] = []
	for id in rooms.keys():
		if int(rooms[id]["tier"]) <= max_tier:
			out.append(id)
	return out
