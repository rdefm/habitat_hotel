class_name PopupHost
extends Control

## A small, anchored popup component (ADR-0011): distinct from
## main_screen.gd's generic full-panel overlay (open_menu()/close_menu()) --
## no title bar, no shared 640x440 panel chrome, just a compact card sized to
## whatever content it's given. Originally matched the prototype's
## .modal-card style (habitat-hotel-prototype-4.html: white, 12px corner
## radius); reskinned to the shared pixel-art theme (ticket 16,
## ui/pixel_theme.gd) so this card reads as part of the same game as the
## world it floats over. Opening pauses the Clock and closing resumes it,
## same as the generic overlay -- callers are responsible for any of their
## own follow-up (e.g. refreshing the hotel panel) since this host has no
## knowledge of game state.

const PixelTheme = preload("res://ui/pixel_theme.gd")

const BACKDROP_COLOR := Color(0, 0, 0, 0.4)

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

	_card = PixelTheme.themed_panel()
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
