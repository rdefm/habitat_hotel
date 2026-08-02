class_name HotelPanel
extends GridContainer

## Visual grid over the hotel's built room instances, addressed by
## room_type_id + per-type instance_id (ADR-0004) instead of a flat slot
## index. A not-yet-unlocked Room type shows no cells at all; an unlocked
## one shows one cell per built instance plus a Build Slot cell (instance_id
## -1) while it's still under its instance cap. Clicking an empty/unlocked
## cell opens Build (scoped to that Floor's Room type) and clicking a built
## room opens Upgrade -- purely a view over GameState, never mutates it
## directly; slot_selected lets the caller decide what to do.
##
## Cells are fully rebuilt on every refresh() rather than updated in place,
## since (unlike the old fixed 18-slot grid) the number of cells now grows
## as Floors are unlocked and built out. A proper per-Floor row layout is
## ticket 03's job -- this is still a flat grid, just addressed differently.

signal slot_selected(room_type_id: String, instance_id: int)

const COLUMNS := 6
const CELL_MIN_SIZE := Vector2(110, 88)

@export var interactive: bool = false


func _ready() -> void:
	columns = COLUMNS
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	refresh()
	EventBus.day_summary.connect(func(_s): refresh())
	EventBus.room_marked_dirty.connect(func(_t, _i): refresh())
	EventBus.room_cleaned.connect(func(_t, _i): refresh())


func refresh() -> void:
	for child in get_children():
		child.queue_free()

	var room_type_ids := GameState.rooms.keys()
	room_type_ids.sort()
	for room_type_id in room_type_ids:
		if not GameState.can_build_room_type(room_type_id):
			continue
		var count := GameState.floor_instance_count(room_type_id)
		for instance_id in range(count):
			add_child(_make_cell(room_type_id, instance_id, GameState.room_instance(room_type_id, instance_id)))
		if GameState.can_build_more(room_type_id):
			add_child(_make_cell(room_type_id, -1, {}))


func _make_cell(room_type_id: String, instance_id: int, room: Dictionary) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = CELL_MIN_SIZE
	btn.toggle_mode = false
	btn.clip_text = true
	btn.pressed.connect(_on_cell_pressed.bind(room_type_id, instance_id))

	var room_type: Dictionary = GameState.rooms[room_type_id]

	if room.is_empty():
		btn.text = "%s\n(build)" % room_type["name"]
		btn.disabled = not interactive
		btn.modulate = Color(1, 1, 1)
		btn.tooltip_text = ""
		return btn

	var occupied := room["occupant"] != null
	var dirty: bool = not occupied and bool(room.get("needs_cleaning", false))
	var upgrade_count: int = room.get("upgrades", []).size()
	var suffix := " ^%d" % upgrade_count if upgrade_count > 0 else ""
	var occupant_line := ""
	var modulate_color := Color(0.85, 0.95, 1.0)
	var tooltip := ""

	if occupied:
		var guest_name: String = room.get("occupant_name", "") if room.get("occupant_name", "") else "Guest"
		var species_id: String = room.get("occupant_species_id", "")
		var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
		var mismatch: bool = room.get("occupant_mismatch", false)
		var fit_text := "mismatch" if mismatch else "perfect fit"
		occupant_line = "\n%s\n%s (%s)" % [guest_name, species_name, fit_text]
		modulate_color = Color(1.0, 0.85, 0.5) if mismatch else Color(0.75, 1.0, 0.75)
		tooltip = "%s the %s -- %s" % [guest_name, species_name, fit_text]
	elif dirty:
		occupant_line = "\n(cleaning)"
		modulate_color = Color(0.8, 0.75, 0.5)
		tooltip = "Being cleaned by housekeeping"

	btn.text = "%s #%d%s%s%s" % [room_type["name"], instance_id, suffix, occupant_line]
	btn.disabled = not interactive
	btn.modulate = modulate_color
	btn.tooltip_text = tooltip
	return btn


func _on_cell_pressed(room_type_id: String, instance_id: int) -> void:
	slot_selected.emit(room_type_id, instance_id)
