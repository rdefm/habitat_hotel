class_name RoomTile
extends PanelContainer

const SpriteFactory = preload("res://game/stubs/sprite_factory.gd")

signal tapped_room(plot_id: int)
signal drop_requested(plot_id: int, party_id: int)

var plot_id: int = -1
var room_type_id: String = ""
var current_fit: String = "NONE"

var _style := StyleBoxFlat.new()
var _name_label: Label
var _pips_holder: Control
var _tags_row: Control
var _clean_bar: ColorRect

func setup(room: Dictionary, room_type: Dictionary) -> void:
	plot_id = int(room["plot_id"])
	room_type_id = String(room["room_type"])
	if get_child_count() == 0:
		_build_static_children()
	_apply_room_data(room, room_type)

func _build_static_children() -> void:
	custom_minimum_size = Vector2(0, 84)
	_style.set_corner_radius_all(8)
	_style.border_width_left = 0
	_style.border_width_right = 0
	_style.border_width_top = 0
	_style.border_width_bottom = 0
	_style.border_color = Color(1, 1, 1, 0)
	add_theme_stylebox_override("panel", _style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	_name_label = SpriteFactory.make_label("", 12)
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_name_label)

	_tags_row = HFlowContainer.new()
	_tags_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_tags_row)

	_pips_holder = HBoxContainer.new()
	_pips_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_pips_holder as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(_pips_holder)

	_clean_bar = ColorRect.new()
	_clean_bar.custom_minimum_size = Vector2(0, 3)
	_clean_bar.color = Color(0.5, 0.75, 0.95)
	_clean_bar.visible = false
	vbox.add_child(_clean_bar)

func _apply_room_data(room: Dictionary, room_type: Dictionary) -> void:
	var room_state: String = String(room["state"])
	_style.bg_color = SpriteFactory.room_state_tint(room_state)

	if room_type.is_empty():
		_name_label.text = "(empty plot)"
		for child in _tags_row.get_children():
			child.queue_free()
		_pips_holder.visible = false
		_clean_bar.visible = false
		return

	_name_label.text = String(room_type.get("display_name", room_type_id))
	for child in _tags_row.get_children():
		child.queue_free()
	for tag in room_type.get("tags", []):
		_tags_row.add_child(SpriteFactory.make_tag_chip(String(tag), false))

	var capacity := int(room_type.get("capacity", 0))
	var occupancy := capacity if room_state == "occupied" else 0
	_pips_holder.visible = true
	for child in _pips_holder.get_children():
		child.queue_free()
	_pips_holder.add_child(SpriteFactory.make_occupancy_pips(occupancy, capacity))

	_clean_bar.visible = room_state == "cleaning"

func set_cleaning_progress(fraction: float) -> void:
	if _clean_bar != null:
		_clean_bar.custom_minimum_size = Vector2(0, 3)
		_clean_bar.size.x = size.x * clampf(fraction, 0.0, 1.0)

func set_glow(fit: String) -> void:
	current_fit = fit
	if fit == "NONE":
		_style.border_width_left = 0
		_style.border_width_right = 0
		_style.border_width_top = 0
		_style.border_width_bottom = 0
	else:
		_style.border_width_left = 3
		_style.border_width_right = 3
		_style.border_width_top = 3
		_style.border_width_bottom = 3
		_style.border_color = SpriteFactory.fit_glow_color(fit)

func flash_fresh() -> void:
	var tween := create_tween()
	modulate = Color(1.5, 1.6, 1.35)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)

func shake_invalid() -> void:
	var tween := create_tween()
	var start_x := position.x
	tween.tween_property(self, "position:x", start_x - 4, 0.04)
	tween.tween_property(self, "position:x", start_x + 4, 0.08)
	tween.tween_property(self, "position:x", start_x, 0.04)

func _gui_input(event: InputEvent) -> void:
	var is_release: Variant = null
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_release = not event.pressed
	elif event is InputEventScreenTouch:
		is_release = not event.pressed
	if is_release == true:
		tapped_room.emit(plot_id)

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("party_id")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if current_fit == "NONE":
		shake_invalid()
		return
	drop_requested.emit(plot_id, int(data["party_id"]))
