class_name SpriteFactory
extends RefCounted

## Every visual entity in game/ is built through this file: ColorRect/Panel
## + Label compositions, no emoji, no downloaded assets, no drawing outside
## this factory. When real pixel art arrives in a later chunk, only this
## file changes.

const SPECIES_COLORS := {
	"pigeon": Color(0.62, 0.62, 0.7),
	"capybara": Color(0.62, 0.47, 0.29),
	"tortoise": Color(0.36, 0.56, 0.31),
	"penguin": Color(0.16, 0.2, 0.28),
	"flamingo": Color(0.95, 0.45, 0.62),
	"bat": Color(0.32, 0.22, 0.38),
	"polar_bear": Color(0.85, 0.88, 0.92),
	"snow_leopard": Color(0.72, 0.74, 0.78),
}

const PATIENCE_COLORS := {
	"content": Color(0.36, 0.68, 0.4),
	"huffy": Color(0.86, 0.65, 0.2),
	"leaving_soon": Color(0.82, 0.28, 0.28),
}

const FIT_COLORS := {
	"GOLD": Color(0.87, 0.72, 0.2),
	"AMBER": Color(0.85, 0.55, 0.22),
}

const ROOM_STATE_TINTS := {
	"empty": Color(0.16, 0.16, 0.18),
	"vacant": Color(0.24, 0.32, 0.26),
	"occupied": Color(0.24, 0.26, 0.34),
	"dirty": Color(0.4, 0.32, 0.2),
	"cleaning": Color(0.32, 0.36, 0.42),
}

static func species_code(species_id: String) -> String:
	if species_id.length() < 2:
		return species_id.to_upper()
	return species_id.substr(0, 2).to_upper()

static func species_color(species_id: String) -> Color:
	return SPECIES_COLORS.get(species_id, Color(0.5, 0.5, 0.5))

## A small labeled rounded panel -- the base building block for chips/tiles.
static func make_panel(size: Vector2, color: Color, corner_radius: int = 8) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	return panel

static func make_label(text: String, font_size: int = 12, color: Color = Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

## Species badge: colored rounded rect + 2-letter code.
static func make_species_badge(species_id: String, size: float = 36.0) -> Control:
	var panel := make_panel(Vector2(size, size), species_color(species_id), int(size * 0.3))
	var label := make_label(species_code(species_id), int(size * 0.32))
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)
	return panel

## A small labeled tag chip. Fainter (lower alpha) for "likes" than "needs".
static func make_tag_chip(tag_name: String, faint: bool = false) -> Control:
	var color := Color(0.3, 0.45, 0.55, 0.55 if faint else 0.9)
	var panel := make_panel(Vector2(0, 18), color, 6)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var label := make_label(tag_name.replace("_", " "), 9)
	label.custom_minimum_size = Vector2(0, 18)
	panel.add_child(label)
	panel.custom_minimum_size = Vector2(max(28.0, tag_name.length() * 6.5), 18)
	return panel

## Patience face: colored dot, green/amber/red per state.
static func make_patience_dot(patience_state: String, size: float = 12.0) -> Control:
	return make_panel(Vector2(size, size), PATIENCE_COLORS.get(patience_state, Color.GRAY), int(size / 2))

static func fit_glow_color(fit: String) -> Color:
	return FIT_COLORS.get(fit, Color(0, 0, 0, 0))

static func room_state_tint(room_state: String) -> Color:
	return ROOM_STATE_TINTS.get(room_state, Color(0.2, 0.2, 0.2))

## Occupancy pips: filled circle per seated guest, hollow outline per empty slot.
static func make_occupancy_pips(occupied: int, capacity: int, pip_size: float = 6.0) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for i in range(capacity):
		var filled := i < occupied
		var pip := make_panel(Vector2(pip_size, pip_size), Color(0.9, 0.9, 0.9, 0.9 if filled else 0.25), int(pip_size / 2))
		row.add_child(pip)
	return row
