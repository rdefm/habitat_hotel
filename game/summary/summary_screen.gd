class_name SummaryScreen
extends PanelContainer

const SpriteFactory = preload("res://game/stubs/sprite_factory.gd")

signal next_day_pressed

func show_summary(summary: Dictionary) -> void:
	for child in get_children():
		child.queue_free()

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11, 0.98)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	vbox.add_child(SpriteFactory.make_label("Day %d complete" % int(summary.get("day", 0)), 16))
	vbox.add_child(SpriteFactory.make_label("Cash: %+d  (now %d)" % [int(summary.get("cash_delta", 0)), int(summary.get("cash_end", 0))], 12))
	vbox.add_child(SpriteFactory.make_label("Seated: %d parties, %d guests" % [int(summary.get("seated_parties", 0)), int(summary.get("seated_guests", 0))], 12))
	vbox.add_child(SpriteFactory.make_label("Perfect fits: %d   Amber seats: %d" % [int(summary.get("gold_seats", 0)), int(summary.get("amber_seats", 0))], 12))
	vbox.add_child(SpriteFactory.make_label("Turned away: %d parties, %d guests" % [int(summary.get("walked_parties", 0)), int(summary.get("walked_guests", 0))], 12))
	vbox.add_child(SpriteFactory.make_label("Checkouts: %d   Mean satisfaction: %.0f" % [int(summary.get("checkouts", 0)), float(summary.get("mean_checkout_satisfaction", 0.0))], 12))
	vbox.add_child(SpriteFactory.make_label("Occupancy: %.0f%%   Rooms cleaned: %d" % [float(summary.get("occupancy_rate", 0.0)) * 100.0, int(summary.get("rooms_cleaned", 0))], 12))

	var btn := Button.new()
	btn.text = "Open tomorrow"
	btn.pressed.connect(func(): next_day_pressed.emit())
	vbox.add_child(btn)

	call_deferred("_recenter")

func _recenter() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
