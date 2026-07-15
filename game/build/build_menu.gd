class_name BuildMenu
extends PanelContainer

const SpriteFactory = preload("res://game/stubs/sprite_factory.gd")

signal room_selected(plot_id: int, room_type_id: String)
signal closed

var _plot_id: int = -1

func open_for_plot(plot_id: int, room_types: Dictionary, max_room_tier: int, cash: int) -> void:
	_plot_id = plot_id
	for child in get_children():
		child.queue_free()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 0.98)
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)
	vbox.add_child(SpriteFactory.make_label("Build on this plot", 14))

	var ids := room_types.keys()
	ids.sort()
	for room_type_id in ids:
		var rt: Dictionary = room_types[room_type_id]
		if int(rt.get("tier", 1)) > max_room_tier:
			continue
		var cost := int(rt.get("build_cost", 0))
		var btn := Button.new()
		btn.text = "%s  (cap %d, tags: %s)  $%d" % [String(rt.get("display_name", room_type_id)), int(rt.get("capacity", 0)), ", ".join(PackedStringArray(rt.get("tags", []))), cost]
		btn.disabled = cash < cost
		btn.pressed.connect(func():
			room_selected.emit(_plot_id, room_type_id)
			visible = false
		)
		vbox.add_child(btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(func():
		visible = false
		closed.emit()
	)
	vbox.add_child(cancel_btn)

	call_deferred("_recenter")

func _recenter() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
