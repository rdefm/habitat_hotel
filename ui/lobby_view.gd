class_name LobbyView
extends Control

## Placeholder lobby visualization. Purely decorative: reacts to EventBus's
## guest_seated/guest_turned_away/guest_checked_out signals by tweening
## simple colored boxes across a fixed strip (entrance -> reception ->
## elevator). Never reads or writes sim state, only GameState.species for
## display names -- same as the other UI files.
##
## Guests who book a room: entrance -> reception -> elevator (fade out,
## "into the elevator" stands in for "now in their room" -- the room grid
## below already shows who's staying where). A bellhop makes a matching
## reception -> elevator -> reception trip carrying their bags.
## Guests turned away: entrance -> reception -> back out.
## Checkouts: elevator -> reception -> back out.

const STRIP_SIZE := Vector2(700, 110)
const ENTRANCE_X := 20.0
const RECEPTION_X := 300.0
const ELEVATOR_X := 620.0
const OFFSCREEN_X := -40.0
const ACTOR_Y := 55.0
const BELLHOP_Y := ACTOR_Y + 28.0
const LEG_DURATION := 0.9
const PAUSE_DURATION := 0.4

var _bellhop: PanelContainer
var _bellhop_tween: Tween


func _ready() -> void:
	custom_minimum_size = STRIP_SIZE
	clip_contents = true

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_add_marker("Entrance", ENTRANCE_X, Color(0.3, 0.3, 0.3))
	_add_marker("Reception", RECEPTION_X, Color(0.25, 0.35, 0.55))
	_add_marker("Elevator", ELEVATOR_X, Color(0.3, 0.3, 0.3))
	_add_marker("Receptionist", RECEPTION_X, Color(0.45, 0.35, 0.55), 30.0)

	_bellhop = _make_actor("Bellhop", Color(0.55, 0.4, 0.2))
	_bellhop.position = Vector2(RECEPTION_X, BELLHOP_Y)
	add_child(_bellhop)

	EventBus.guest_seated.connect(_on_guest_seated)
	EventBus.guest_turned_away.connect(_on_guest_turned_away)
	EventBus.guest_checked_out.connect(_on_guest_checked_out)


func _add_marker(text: String, x: float, color: Color, y: float = 10.0) -> void:
	var marker := _make_actor(text, color)
	marker.position = Vector2(x, y)
	add_child(marker)


func _make_actor(text: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	panel.add_child(label)
	return panel


func _guest_color(mismatch: bool) -> Color:
	return Color(0.75, 0.55, 0.2) if mismatch else Color(0.3, 0.55, 0.3)


func _short_name(guest_name: String) -> String:
	return guest_name if guest_name.length() <= 12 else guest_name.substr(0, 11) + "."


func _species_name(species_id: String) -> String:
	return GameState.species.get(species_id, {}).get("name", species_id)


func _on_guest_seated(guest_name: String, species_id: String, _room_slot_index: int, mismatch: bool) -> void:
	var guest := _make_actor(_short_name(guest_name), _guest_color(mismatch))
	guest.tooltip_text = "%s the %s -- %s" % [guest_name, _species_name(species_id), ("mismatch" if mismatch else "perfect fit")]
	guest.position = Vector2(ENTRANCE_X, ACTOR_Y)
	add_child(guest)

	var tween := create_tween()
	tween.tween_property(guest, "position:x", RECEPTION_X, LEG_DURATION)
	tween.tween_interval(PAUSE_DURATION)
	tween.tween_property(guest, "position:x", ELEVATOR_X, LEG_DURATION)
	tween.tween_interval(0.2)
	tween.tween_property(guest, "modulate:a", 0.0, 0.3)
	tween.tween_callback(guest.queue_free)

	_send_bellhop()


func _on_guest_turned_away(guest_name: String, species_id: String, reason: String) -> void:
	var guest := _make_actor(_short_name(guest_name), Color(0.55, 0.2, 0.2))
	guest.tooltip_text = "%s the %s -- turned away (%s)" % [guest_name, _species_name(species_id), reason]
	guest.position = Vector2(ENTRANCE_X, ACTOR_Y)
	add_child(guest)

	var tween := create_tween()
	tween.tween_property(guest, "position:x", RECEPTION_X, LEG_DURATION)
	tween.tween_interval(PAUSE_DURATION)
	tween.tween_property(guest, "position:x", OFFSCREEN_X, LEG_DURATION)
	tween.tween_callback(guest.queue_free)


func _on_guest_checked_out(guest_name: String, species_id: String, _room_slot_index: int) -> void:
	var guest := _make_actor(_short_name(guest_name), Color(0.4, 0.4, 0.5))
	guest.tooltip_text = "%s the %s -- checking out" % [guest_name, _species_name(species_id)]
	guest.position = Vector2(ELEVATOR_X, ACTOR_Y)
	add_child(guest)

	var tween := create_tween()
	tween.tween_property(guest, "position:x", RECEPTION_X, LEG_DURATION)
	tween.tween_interval(PAUSE_DURATION)
	tween.tween_property(guest, "position:x", OFFSCREEN_X, LEG_DURATION)
	tween.tween_callback(guest.queue_free)


## Bellhop makes one reception->elevator->reception round trip per seated
## guest. If a trip is already underway, cut it short and start the new one
## -- good enough for a placeholder; a real queue can wait for the art pass.
func _send_bellhop() -> void:
	if _bellhop_tween != null and _bellhop_tween.is_valid():
		_bellhop_tween.kill()
	_bellhop.position = Vector2(RECEPTION_X, BELLHOP_Y)

	_bellhop_tween = create_tween()
	_bellhop_tween.tween_interval(0.3)
	_bellhop_tween.tween_property(_bellhop, "position:x", ELEVATOR_X, LEG_DURATION)
	_bellhop_tween.tween_interval(0.3)
	_bellhop_tween.tween_property(_bellhop, "position:x", RECEPTION_X, LEG_DURATION)
