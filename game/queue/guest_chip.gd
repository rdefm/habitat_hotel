class_name GuestChip
extends PanelContainer

const SpriteFactory = preload("res://game/stubs/sprite_factory.gd")

## Press selects (soft-slow + glow); selection persists past release until
## the player resolves it (re-tap to deselect, tap a room, or seat) -- see
## DECISIONS.md for why "held" was resolved to a persistent selection
## rather than a strict press-and-hold gesture.
signal pressed_chip(party_id: int)

var party_id: int = -1
var species_id: String = ""
var party_count: int = 1

func setup(entry: Dictionary, species: Dictionary, patience_state_value: String) -> void:
	party_id = int(entry["party_id"])
	species_id = String(entry["species_id"])
	party_count = int(entry["party_count"])
	_rebuild(species.get("needs", []), species.get("likes", []), patience_state_value)

func _rebuild(needs: Array, likes: Array, patience_state_value: String) -> void:
	for child in get_children():
		child.queue_free()

	custom_minimum_size = Vector2(100, 116)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.14, 0.17, 0.95)
	style.set_corner_radius_all(10)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(SpriteFactory.make_species_badge(species_id))
	vbox.add_child(top_row)

	vbox.add_child(SpriteFactory.make_label("x%d" % party_count, 11))

	var needs_row := HFlowContainer.new()
	needs_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for n in needs:
		needs_row.add_child(SpriteFactory.make_tag_chip(String(n), false))
	vbox.add_child(needs_row)

	var likes_row := HFlowContainer.new()
	likes_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in likes:
		likes_row.add_child(SpriteFactory.make_tag_chip(String(l), true))
	vbox.add_child(likes_row)

	var dot_row := HBoxContainer.new()
	dot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_row.add_child(SpriteFactory.make_patience_dot(patience_state_value))
	vbox.add_child(dot_row)

func _gui_input(event: InputEvent) -> void:
	var is_press := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		is_press = true
	elif event is InputEventScreenTouch and event.pressed:
		is_press = true
	if is_press:
		pressed_chip.emit(party_id)

func _get_drag_data(_at_position: Vector2) -> Variant:
	pressed_chip.emit(party_id)
	var preview := SpriteFactory.make_species_badge(species_id, 44)
	preview.modulate.a = 0.85
	set_drag_preview(preview)
	return {"party_id": party_id}
