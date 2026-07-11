class_name UpgradeMenu
extends VBoxContainer

## Upgrade menu for one built room instance: shows its current effective
## stats, already-purchased upgrades, and any remaining ones to buy. Opened
## by tapping a built room in the (now-interactive) hotel grid.

var slot_index: int = -1

var _stats_label: Label
var _purchased_list: VBoxContainer
var _available_list: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(520, 420)

	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_stats_label)

	var purchased_header := Label.new()
	purchased_header.text = "Purchased upgrades:"
	add_child(purchased_header)
	_purchased_list = VBoxContainer.new()
	add_child(_purchased_list)

	var available_header := Label.new()
	available_header.text = "Available upgrades:"
	add_child(available_header)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	_available_list = VBoxContainer.new()
	_available_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_available_list)

	_refresh()


func _refresh() -> void:
	var room := GameState.room_at_slot(slot_index)
	if room.is_empty():
		_stats_label.text = "This room no longer exists."
		return

	var base: Dictionary = GameState.rooms[room["room_type_id"]]
	var stats := GameState.effective_room_stats(room)
	_stats_label.text = "%s (slot %d)\ntags=%s  capacity=%d  upkeep=%d/day  rate=%d/night%s" % [
		base["name"], slot_index, stats["tags"], int(stats["capacity"]), int(stats["upkeep_per_day"]), int(base["base_rate"]),
		("  satisfaction +%d" % int(stats["satisfaction_bonus"])) if float(stats.get("satisfaction_bonus", 0)) != 0.0 else "",
	]

	for child in _purchased_list.get_children():
		child.queue_free()
	var purchased: Array = room.get("upgrades", [])
	if purchased.is_empty():
		_purchased_list.add_child(_label("(none yet)"))
	else:
		for upgrade_id in purchased:
			var upgrade := _find_upgrade(base, upgrade_id)
			_purchased_list.add_child(_label("- %s: %s" % [upgrade.get("name", upgrade_id), upgrade.get("description", "")]))

	for child in _available_list.get_children():
		child.queue_free()
	var available: Array = GameState.available_upgrades_for(room)
	if available.is_empty():
		_available_list.add_child(_label("No more upgrades for this room type."))
	for upgrade in available:
		_available_list.add_child(_build_upgrade_row(upgrade))


func _build_upgrade_row(upgrade: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var info := Label.new()
	info.text = "%s -- %s (%d cash, %d hearts)" % [
		upgrade["name"], upgrade["description"], int(upgrade["cost_cash"]), int(upgrade["cost_hearts"]),
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(320, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.disabled = GameState.cash < int(upgrade["cost_cash"]) or GameState.hearts < int(upgrade["cost_hearts"])
	buy_btn.pressed.connect(_on_buy_pressed.bind(upgrade["id"]))
	row.add_child(buy_btn)

	return row


func _on_buy_pressed(upgrade_id: String) -> void:
	if GameState.purchase_upgrade(slot_index, upgrade_id):
		_refresh()


func _find_upgrade(room_type: Dictionary, upgrade_id: String) -> Dictionary:
	for upgrade in room_type.get("upgrades", []):
		if upgrade["id"] == upgrade_id:
			return upgrade
	return {}


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
