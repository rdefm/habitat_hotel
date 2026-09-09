class_name PixelTheme
extends RefCounted

## Shared pixel-art modal theme (ticket 16, spec.md "HUD, toasts, and
## modals"): every surviving modal -- PopupHost's bespoke small popups
## (ADR-0011) and main_screen.gd's generic full-panel overlay -- gets this
## Theme applied once, at its own root Control. Godot's ordinary theme
## propagation down the tree does the rest: every Button/Label/TabContainer/
## OptionButton a modal script builds (seat_confirm_menu.gd,
## build_confirm_menu.gd, stay_info_menu.gd, staffer_detail_menu.gd,
## upgrade_menu.gd, terrace_menu.gd, reception_menu.gd and its Prices/Hire/
## Reports/Reviews tabs) inherits these styles automatically, with no change
## to any individual modal file, its content, controls or Sim/GameState
## calls, per spec.
##
## Palette borrows from what the world already established rather than
## inventing a second one: the dark-panel-plus-warm-gold read of
## ui/hud_strip.gd's backing/gear-popover colors and its Reputation fill
## gold. Flat, zero-corner-radius StyleBoxFlats with anti_aliasing off and a
## thick single-tone border are the "pixel-art" read here -- crisp blocky
## chrome rather than the engine's default soft-bevelled panels/buttons.
##
## No pixel bitmap font asset exists yet (docs/asset_contract.md has no font
## slot for one) -- "sharing the world's font" means not introducing a
## second font family, which staying on the engine default font already
## guarantees; only size, color and a 1px drop shadow (the same technique
## ui/hud_strip.gd's pill labels already use) are themed here, the same
## placeholder-until-asset-lands convention every other unstyled slot in
## this codebase follows.

const PANEL_BG := Color(0.11, 0.09, 0.16)
const BORDER := Color(0.95, 0.78, 0.35)
const TEXT := Color(0.96, 0.93, 0.85)
const TEXT_DISABLED := Color(0.55, 0.52, 0.5)
const SHADOW := Color(0, 0, 0, 0.85)

const BUTTON_BG := Color(0.24, 0.19, 0.32)
const BUTTON_HOVER := Color(0.32, 0.25, 0.42)
const BUTTON_PRESSED := Color(0.07, 0.06, 0.11)
const BUTTON_DISABLED := Color(0.16, 0.14, 0.18)

const BORDER_WIDTH := 3
const FONT_SIZE := 16
const PANEL_PADDING := 16


## Builds a fresh themed Theme resource. Called once per host Control
## (PopupHost's card, main_screen.gd's overlay panel) at _ready() time, not
## per modal open -- cheap enough that no caching is worth the complexity.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = FONT_SIZE

	theme.set_stylebox("panel", "PanelContainer", panel_style())

	theme.set_stylebox("normal", "Button", _button_style(BUTTON_BG))
	theme.set_stylebox("hover", "Button", _button_style(BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _button_style(BUTTON_PRESSED))
	theme.set_stylebox("hover_pressed", "Button", _button_style(BUTTON_PRESSED))
	theme.set_stylebox("disabled", "Button", _button_style(BUTTON_DISABLED))
	theme.set_stylebox("focus", "Button", _focus_style())
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", TEXT_DISABLED)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_shadow_color", "Button", SHADOW)
	theme.set_constant("shadow_offset_x", "Button", 1)
	theme.set_constant("shadow_offset_y", "Button", 1)

	theme.set_stylebox("normal", "OptionButton", _button_style(BUTTON_BG))
	theme.set_stylebox("hover", "OptionButton", _button_style(BUTTON_HOVER))
	theme.set_stylebox("pressed", "OptionButton", _button_style(BUTTON_PRESSED))
	theme.set_stylebox("disabled", "OptionButton", _button_style(BUTTON_DISABLED))
	theme.set_stylebox("focus", "OptionButton", _focus_style())
	theme.set_color("font_color", "OptionButton", TEXT)
	theme.set_color("font_hover_color", "OptionButton", TEXT)
	theme.set_color("font_disabled_color", "OptionButton", TEXT_DISABLED)

	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_shadow_color", "Label", SHADOW)
	theme.set_constant("shadow_offset_x", "Label", 1)
	theme.set_constant("shadow_offset_y", "Label", 1)

	theme.set_stylebox("panel", "TabContainer", panel_style())
	theme.set_stylebox("tab_selected", "TabContainer", _tab_style(BUTTON_BG, true))
	theme.set_stylebox("tab_unselected", "TabContainer", _tab_style(PANEL_BG, false))
	theme.set_stylebox("tab_hovered", "TabContainer", _tab_style(BUTTON_HOVER, false))
	theme.set_color("font_selected_color", "TabContainer", TEXT)
	theme.set_color("font_unselected_color", "TabContainer", TEXT_DISABLED)
	theme.set_color("font_hovered_color", "TabContainer", TEXT)

	theme.set_stylebox("panel", "PopupMenu", panel_style())
	theme.set_stylebox("hover", "PopupMenu", _button_style(BUTTON_HOVER))
	theme.set_color("font_color", "PopupMenu", TEXT)
	theme.set_color("font_hover_color", "PopupMenu", TEXT)

	return theme


## The one construction PopupHost's card and main_screen.gd's overlay panel
## both need -- a themed PanelContainer with the shared panel look already
## applied -- folded into a single call so neither host repeats the
## theme-plus-stylebox wiring. Callers still set their own
## custom_minimum_size/clip_contents afterwards.
static func themed_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme = build()
	panel.add_theme_stylebox_override("panel", panel_style())
	return panel


## The shared panel look -- also used directly by themed_panel() above for
## the one panel StyleBox each host hands its PanelContainer explicitly (the
## "panel" theme entry set in build() covers every *other* PanelContainer a
## modal script builds internally without either caller repeating itself).
static func panel_style() -> StyleBoxFlat:
	var box := _flat_box(PANEL_BG)
	box.content_margin_left = PANEL_PADDING
	box.content_margin_right = PANEL_PADDING
	box.content_margin_top = PANEL_PADDING
	box.content_margin_bottom = PANEL_PADDING
	return box


static func _button_style(bg: Color) -> StyleBoxFlat:
	var box := _flat_box(bg)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func _tab_style(bg: Color, selected: bool) -> StyleBoxFlat:
	var box := _flat_box(bg)
	box.border_width_bottom = 0 if selected else BORDER_WIDTH
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box


static func _focus_style() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.set_border_width_all(BORDER_WIDTH)
	box.border_color = BORDER
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	return box


static func _flat_box(bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.set_border_width_all(BORDER_WIDTH)
	box.border_color = BORDER
	box.set_corner_radius_all(0)
	box.anti_aliasing = false
	return box
