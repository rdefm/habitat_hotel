class_name LobbyView
extends Control

## Placeholder lobby visualization. Purely decorative: reacts to EventBus's
## room_marked_dirty signal by tweening a simple colored-box housekeeper
## across a fixed strip (reception -> elevator -> reception). Never reads or
## writes sim state, only GameState.species for display names -- same as the
## other UI files.
##
## guest_seated (ticket 04) and guest_turned_away/guest_checked_out (ticket
## 05, ADR-0016) are no longer handled here: a seated guest's real walk from
## Reception to their Room, a turned-away guest's real walk out from its
## actual Reception queue position, and a checking-out guest's real walk
## down from their Room, all now live in ui/room_occupancy_layer.gd -- this
## file's old fixed entrance/reception/elevator stand-in trips (plus its
## decorative, disconnected bellhop round-trip) were exactly the abstracted
## stand-ins those tickets replace.
##
## A housekeeper makes a reception -> elevator -> reception trip whenever a
## room is checked out and marked dirty, standing in for "went and cleaned
## that room"; between trips it idles near reception. (Ticket 09 will give
## this the same real-target treatment ticket 04 gave the guest walk-in.)
##
## The sim can mark several rooms dirty in one instant (a busy checkout
## phase); rather than playing every resulting trip at once, incoming events
## are queued and drip-fed one at a time so a busy phase still reads as a
## trickle of activity instead of a single dump. This is purely a
## presentation choice -- the sim's timing and results are unaffected.

const STRIP_SIZE := Vector2(700, 110)
const RECEPTION_X := 300.0
const ELEVATOR_X := 620.0
const HOUSEKEEPER_Y := 83.0
const LEG_DURATION := 0.9

## Bounds on how far apart queued events are staggered: never faster than
## MIN (so a big batch doesn't blur together) nor slower than MAX (so a
## single lone event doesn't crawl).
const MIN_QUEUE_INTERVAL := 0.35
const MAX_QUEUE_INTERVAL := 1.5
const HOUSEKEEPER_IDLE_INTERVAL := 4.0

var _housekeeper: PanelContainer
var _housekeeper_tween: Tween
var _housekeeper_idle_timer: Timer

# Queued presentation events awaiting playback, drip-fed by _dequeue_timer
# rather than played the instant they arrive -- see class doc above.
var _event_queue: Array[Dictionary] = []
var _dequeue_timer: Timer


func _ready() -> void:
	custom_minimum_size = STRIP_SIZE
	clip_contents = true

	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.12, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_add_marker("Reception", RECEPTION_X, Color(0.25, 0.35, 0.55))
	_add_marker("Elevator", ELEVATOR_X, Color(0.3, 0.3, 0.3))
	_add_marker("Receptionist", RECEPTION_X, Color(0.45, 0.35, 0.55), 30.0)

	_housekeeper = _make_actor("Housekeeper", Color(0.3, 0.55, 0.5))
	_housekeeper.position = Vector2(RECEPTION_X, HOUSEKEEPER_Y)
	add_child(_housekeeper)

	_housekeeper_idle_timer = Timer.new()
	_housekeeper_idle_timer.wait_time = HOUSEKEEPER_IDLE_INTERVAL
	_housekeeper_idle_timer.timeout.connect(_on_housekeeper_idle_tick)
	add_child(_housekeeper_idle_timer)
	_housekeeper_idle_timer.start()

	_dequeue_timer = Timer.new()
	_dequeue_timer.one_shot = true
	_dequeue_timer.timeout.connect(_on_dequeue_timer_timeout)
	add_child(_dequeue_timer)

	EventBus.room_marked_dirty.connect(_on_room_marked_dirty)
	EventBus.clock_paused_changed.connect(_on_clock_paused_changed)


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


## --- Event queue: signals only enqueue; _play_* does the actual animating ---

func _on_room_marked_dirty(room_type_id: String, instance_id: int) -> void:
	_enqueue({"kind": "dirty", "room_type_id": room_type_id, "instance_id": instance_id})


func _enqueue(entry: Dictionary) -> void:
	_event_queue.append(entry)
	if _dequeue_timer.is_stopped() and not Clock.paused:
		_dequeue_timer.start(_compute_queue_interval())


func _on_dequeue_timer_timeout() -> void:
	if _event_queue.is_empty():
		return
	var entry: Dictionary = _event_queue.pop_front()
	_play_entry(entry)
	if not _event_queue.is_empty() and not Clock.paused:
		_dequeue_timer.start(_compute_queue_interval())


func _on_clock_paused_changed(is_paused: bool) -> void:
	if is_paused:
		_dequeue_timer.stop()
	elif not _event_queue.is_empty():
		_dequeue_timer.start(_compute_queue_interval())


## Spreads whatever's left in the queue evenly across the current phase's
## remaining real time (reusing Clock's own phase table rather than
## duplicating phase durations here), clamped to a sane pacing window.
func _compute_queue_interval() -> float:
	var remaining_ticks := _ticks_remaining_in_phase()
	var speed := maxf(Clock.speed, 0.01)
	var remaining_seconds := (float(remaining_ticks) * Clock.TICK_DURATION) / speed
	var denom := _event_queue.size() + 1
	return clampf(remaining_seconds / float(denom), MIN_QUEUE_INTERVAL, MAX_QUEUE_INTERVAL)


func _ticks_remaining_in_phase() -> int:
	var boundaries: Array = []
	for pair in Clock.PHASE_START_TICKS:
		boundaries.append(int(pair[1]))
	boundaries.append(Clock.TICKS_PER_DAY + 1)
	var tick: int = Clock.tick_in_day
	for boundary in boundaries:
		if boundary > tick:
			return boundary - tick
	return 1


func _play_entry(entry: Dictionary) -> void:
	match entry["kind"]:
		"dirty":
			_play_room_dirty(entry["room_type_id"], entry["instance_id"])


## --- Playback (each runs exactly once per dequeued event) ---

func _play_room_dirty(_room_type_id: String, _instance_id: int) -> void:
	_send_housekeeper()


## Housekeeper makes a reception->elevator->reception round trip per dirtied
## room. If a trip is already underway, cut it short and start the new one
## -- good enough for a placeholder; a real queue can wait for the art pass.
func _send_housekeeper() -> void:
	if _housekeeper_tween != null and _housekeeper_tween.is_valid():
		_housekeeper_tween.kill()
	_housekeeper.position = Vector2(RECEPTION_X, HOUSEKEEPER_Y)

	_housekeeper_tween = create_tween()
	_housekeeper_tween.tween_interval(0.3)
	_housekeeper_tween.tween_property(_housekeeper, "position:x", ELEVATOR_X, LEG_DURATION)
	_housekeeper_tween.tween_interval(0.3)
	_housekeeper_tween.tween_property(_housekeeper, "position:x", RECEPTION_X, LEG_DURATION)


## Ambient "tidying up reception" flavor for whenever the housekeeper isn't
## off on a cleaning trip -- this view is only an abstract strip (Reception/
## Elevator), not a real hotel map, so "wanders around fixing things" is
## represented as a small idle bounce in place rather than actual pathing to
## arbitrary spots.
func _on_housekeeper_idle_tick() -> void:
	if _housekeeper_tween != null and _housekeeper_tween.is_valid():
		return
	var nudge := create_tween()
	nudge.tween_property(_housekeeper, "position:y", HOUSEKEEPER_Y - 6.0, 0.25)
	nudge.tween_property(_housekeeper, "position:y", HOUSEKEEPER_Y, 0.25)
