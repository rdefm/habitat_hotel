class_name SimSave
extends RefCounted

const SimState = preload("res://sim/sim_state.gd")

## Versioned JSON serialize/deserialize of sim_state. Written to
## user://save.json at each Night phase (see sim_game.gd). Loading a higher
## schema_version than this build knows about fails gracefully (returns
## null) rather than corrupting state.

static func serialize(state: SimState) -> Dictionary:
	var out: Dictionary = {}
	for prop in state.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
			continue
		var name: String = prop["name"]
		out[name] = state.get(name)
	return out

static func to_json(state: SimState) -> String:
	return JSON.stringify(serialize(state))

static func from_dict(data: Dictionary) -> SimState:
	var state := SimState.new()
	for key in data.keys():
		state.set(key, data[key])
	return state

static func from_json(text: String) -> SimState:
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("SimSave: failed to parse save JSON")
		return null
	if int(parsed.get("schema_version", -1)) > SimState.SCHEMA_VERSION:
		push_error("SimSave: save schema_version %s is newer than this build supports (%s)" % [parsed.get("schema_version"), SimState.SCHEMA_VERSION])
		return null
	return from_dict(parsed)

static func write_to_file(state: SimState, path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SimSave: could not open %s for writing (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(to_json(state))
	file.close()
	return true

static func read_from_file(path: String) -> SimState:
	if not FileAccess.file_exists(path):
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	return from_json(text)
