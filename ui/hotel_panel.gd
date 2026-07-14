class_name HotelPanel
extends GridContainer

## Visual grid of the hotel's 18 slots (3 floors x 6), per section 3.4.
## Used two ways: an interactive copy on the main screen, where clicking an
## empty unlocked slot opens Build and clicking a built room opens Upgrade;
## and an interactive copy inside the Build menu itself, scoped to picking
## an empty slot only. Purely a view over GameState -- never mutates it
## directly; the slot_selected signal lets each context decide what to do.

signal slot_selected(slot_index: int)

const COLUMNS := 6
const CELL_MIN_SIZE := Vector2(110, 72)

@export var interactive: bool = false

var _cell_buttons: Dictionary = {} # slot_index -> Button


func _ready() -> void:
	columns = COLUMNS
	add_theme_constant_override("h_separation", 4)
	add_theme_constant_override("v_separation", 4)
	_build_cells()
	refresh()
	EventBus.day_summary.connect(func(_s): refresh())


func _build_cells() -> void:
	for child in get_children():
		child.queue_free()
	_cell_buttons.clear()

	var slots := GameState.slot_layout.duplicate()
	slots.sort_custom(func(a, b): return int(a["slot"]) < int(b["slot"]))

	for entry in slots:
		var slot_index: int = int(entry["slot"])
		var btn := Button.new()
		btn.custom_minimum_size = CELL_MIN_SIZE
		btn.toggle_mode = false
		btn.clip_text = true
		btn.disabled = not interactive
		btn.pressed.connect(_on_cell_pressed.bind(slot_index))
		add_child(btn)
		_cell_buttons[slot_index] = btn


func refresh() -> void:
	for slot_index in _cell_buttons.keys():
		var btn: Button = _cell_buttons[slot_index]
		var unlocked := GameState.is_slot_unlocked(slot_index)
		var room := GameState.room_at_slot(slot_index)

		if not unlocked:
			btn.text = "Slot %d\n[locked]" % slot_index
			btn.disabled = true
			btn.modulate = Color(0.5, 0.5, 0.5)
		elif room.is_empty():
			btn.text = "Slot %d\n(empty)" % slot_index
			btn.disabled = not interactive
			btn.modulate = Color(1, 1, 1)
		else:
			var room_type: Dictionary = GameState.rooms[room["room_type_id"]]
			var occupied := room["occupant"] != null
			var upgrade_count: int = room.get("upgrades", []).size()
			var suffix := " ^%d" % upgrade_count if upgrade_count > 0 else ""
			var occupant_line := ""
			var modulate_color := Color(0.85, 0.95, 1.0)

			if occupied:
				var species_id: String = room.get("occupant_species_id", "")
				var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
				var mismatch: bool = room.get("occupant_mismatch", false)
				occupant_line = "\n%s%s" % [species_name, (" (mismatch)" if mismatch else " (perfect fit)")]
				modulate_color = Color(1.0, 0.85, 0.5) if mismatch else Color(0.75, 1.0, 0.75)

			btn.text = "Slot %d\n%s%s%s" % [slot_index, room_type["name"], suffix, occupant_line]
			btn.disabled = not interactive
			btn.modulate = modulate_color


func _on_cell_pressed(slot_index: int) -> void:
	slot_selected.emit(slot_index)
