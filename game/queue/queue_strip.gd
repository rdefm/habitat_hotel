class_name QueueStrip
extends ScrollContainer

const GuestChip = preload("res://game/queue/guest_chip.gd")
const SimQueue = preload("res://sim/sim_queue.gd")

signal chip_pressed(party_id: int)

var _row: HBoxContainer
var _chips: Dictionary = {}

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	custom_minimum_size = Vector2(0, 124)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 6)
	add_child(_row)

func refresh(queue: Array, species_table: Dictionary, balance: Dictionary) -> void:
	var seen: Dictionary = {}
	for entry in queue:
		var party_id := int(entry["party_id"])
		seen[party_id] = true
		var species: Dictionary = species_table.get(entry["species_id"], {})
		var patience_state_value := SimQueue.patience_state(entry, balance)
		var chip: GuestChip = _chips.get(party_id)
		if chip == null:
			chip = GuestChip.new()
			chip.pressed_chip.connect(func(pid: int): chip_pressed.emit(pid))
			_row.add_child(chip)
			_chips[party_id] = chip
		chip.setup(entry, species, patience_state_value)

	for party_id in _chips.keys().duplicate():
		if not seen.has(party_id):
			_chips[party_id].queue_free()
			_chips.erase(party_id)
