class_name PopupHost
extends Control

## A small, anchored popup component (ADR-0011): distinct from
## main_screen.gd's generic full-panel overlay (open_menu()/close_menu()) --
## no title bar, no shared 640x440 panel chrome, just a compact rounded card
## sized to whatever content it's given. Matches the prototype's
## .modal-card style (habitat-hotel-prototype-4.html): white, 12px corner
## radius, padded. Opening pauses the Clock and closing resumes it, same as
## the generic overlay -- callers are responsible for any of their own
## follow-up (e.g. refreshing the hotel panel) since this host has no
## knowledge of game state.

const CARD_COLOR := Color(1, 1, 1)
const BACKDROP_COLOR := Color(0, 0, 0, 0.4)
const CARD_CORNER_RADIUS := 12
const CARD_PADDING := 16

var _card: PanelContainer
var _content: Control


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_card = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_COLOR
	style.set_corner_radius_all(CARD_CORNER_RADIUS)
	style.content_margin_left = CARD_PADDING
	style.content_margin_right = CARD_PADDING
	style.content_margin_top = CARD_PADDING
	style.content_margin_bottom = CARD_PADDING
	_card.add_theme_stylebox_override("panel", style)
	center.add_child(_card)


## Shows the popup with `content` inside the card and pauses the Clock.
## Replaces whatever content is already showing, if any.
func open_popup(content: Control) -> void:
	if _content != null:
		_content.queue_free()
	_content = content
	_card.add_child(content)
	visible = true
	Clock.set_paused(true)


## Hides the popup, frees its content, and resumes the Clock.
func close_popup() -> void:
	visible = false
	if _content != null:
		_content.queue_free()
		_content = null
	Clock.set_paused(false)
