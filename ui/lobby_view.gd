class_name LobbyView
extends Control

## Placeholder lobby visualization. Purely decorative: reacts to EventBus's
## guest_seated/guest_turned_away/guest_checked_out/room_marked_dirty
## signals by tweening simple colored boxes across a fixed strip (entrance ->
## reception -> elevator). Never reads or writes sim state, only
## GameState.species for display names -- same as the other UI files.
##
## Guests who book a room: entrance -> reception -> elevator (fade out,
## "into the elevator" stands in for "now in their room" -- the room grid
## below already shows who's staying where). A bellhop makes a matching
## reception -> elevator -> reception trip carrying their bags.
## Guests turned away: entrance -> reception -> back out.
## Checkouts: elevator -> reception -> back out.
## A housekeeper makes the same reception -> elevator -> reception trip
## whenever a room is checked out and marked dirty, standing in for "went
## and cleaned that room" the same way the elevator already stands in for
## "now in their room"; between trips it idles near reception.
##
## The sim resolves a whole phase's worth of arrivals/checkouts in one
## instant (see autoload/sim_controller.gd); rather than playing every
## resulting animation at once, incoming events are queued and drip-fed one
## at a time so a busy phase still reads as a trickle of activity instead of
## a single dump. This is purely a presentation choice -- the sim's timing
## and results are unaffected.

const STRIP_SIZE := Vector2(700, 110)
const ENTRANCE_X := 20.0
const RECEPTION_X := 300.0
const ELEVATOR_X := 620.0
const OFFSCREEN_X := -40.0
const ACTOR_Y := 55.0
const BELLHOP_Y := ACTOR_Y + 28.0
const HOUSEKEEPER_Y := BELLHOP_Y + 28.0
const LEG_DURATION := 0.9
const PAUSE_DURATION := 0.4

## Bounds on how far apart queued events are staggered: never faster than
## MIN (so a big batch doesn't blur together) nor slower than MAX (so a
## single lone event doesn't crawl).
const MIN_QUEUE_INTERVAL := 0.35
const MAX_QUEUE_INTERVAL := 1.5
const HOUSEKEEPER_IDLE_INTERVAL := 4.0

var _bellhop: PanelContainer
var _bellhop_tween: Tween

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

	_add_marker("Entrance", ENTRANCE_X, Color(0.3, 0.3, 0.3))
	_add_marker("Reception", RECEPTION_X, Color(0.25, 0.35, 0.55))
	_add_marker("Elevator", ELEVATOR_X, Color(0.3, 0.3, 0.3))
	_add_marker("Receptionist", RECEPTION_X, Color(0.45, 0.35, 0.55), 30.0)

	_bellhop = _make_actor("Bellhop", Color(0.55, 0.4, 0.2))
	_bellhop.position = Vector2(RECEPTION_X, BELLHOP_Y)
	add_child(_bellhop)

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

	EventBus.guest_seated.connect(_on_guest_seated)
	EventBus.guest_turned_away.connect(_on_guest_turned_away)
	EventBus.guest_checked_out.connect(_on_guest_checked_out)
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


func _guest_color(mismatch: bool) -> Color:
	return Color(0.75, 0.55, 0.2) if mismatch else Color(0.3, 0.55, 0.3)


func _short_name(guest_name: String) -> String:
	return guest_name if guest_name.length() <= 12 else guest_name.substr(0, 11) + "."


func _species_name(species_id: String) -> String:
	return GameState.species.get(species_id, {}).get("name", species_id)


## --- Event queue: signals only enqueue; _play_* does the actual animating ---

func _on_guest_seated(guest_name: String, species_id: String, room_slot_index: int, mismatch: bool) -> void:
	_enqueue({
		"kind": "seated", "guest_name": guest_name, "species_id": species_id,
		"room_slot_index": room_slot_index, "mismatch": mismatch,
	})


func _on_guest_turned_away(guest_name: String, species_id: String, reason: String) -> void:
	_enqueue({"kind": "turned_away", "guest_name": guest_name, "species_id": species_id, "reason": reason})


func _on_guest_checked_out(guest_name: String, species_id: String, room_slot_index: int) -> void:
	_enqueue({"kind": "checked_out", "guest_name": guest_name, "species_id": species_id, "room_slot_index": room_slot_index})


func _on_room_marked_dirty(slot_index: int) -> void:
	_enqueue({"kind": "dirty", "slot_index": slot_index})


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
		"seated":
			_play_guest_seated(entry["guest_name"], entry["species_id"], entry["room_slot_index"], entry["mismatch"])
		"turned_away":
			_play_guest_turned_away(entry["guest_name"], entry["species_id"], entry["reason"])
		"checked_out":
			_play_guest_checked_out(entry["guest_name"], entry["species_id"], entry["room_slot_index"])
		"dirty":
			_play_room_dirty(entry["slot_index"])


## --- Playback (each runs exactly once per dequeued event) ---

func _play_guest_seated(guest_name: String, species_id: String, _room_slot_index: int, mismatch: bool) -> void:
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


func _play_guest_turned_away(guest_name: String, species_id: String, reason: String) -> void:
	var guest := _make_actor(_short_name(guest_name), Color(0.55, 0.2, 0.2))
	guest.tooltip_text = "%s the %s -- turned away (%s)" % [guest_name, _species_name(species_id), reason]
	guest.position = Vector2(ENTRANCE_X, ACTOR_Y)
	add_child(guest)

	var tween := create_tween()
	tween.tween_property(guest, "position:x", RECEPTION_X, LEG_DURATION)
	tween.tween_interval(PAUSE_DURATION)
	tween.tween_property(guest, "position:x", OFFSCREEN_X, LEG_DURATION)
	tween.tween_callback(guest.queue_free)


func _play_guest_checked_out(guest_name: String, species_id: String, _room_slot_index: int) -> void:
	var guest := _make_actor(_short_name(guest_name), Color(0.4, 0.4, 0.5))
	guest.tooltip_text = "%s the %s -- checking out" % [guest_name, _species_name(species_id)]
	guest.position = Vector2(ELEVATOR_X, ACTOR_Y)
	add_child(guest)

	var tween := create_tween()
	tween.tween_property(guest, "position:x", RECEPTION_X, LEG_DURATION)
	tween.tween_interval(PAUSE_DURATION)
	tween.tween_property(guest, "position:x", OFFSCREEN_X, LEG_DURATION)
	tween.tween_callback(guest.queue_free)


func _play_room_dirty(_slot_index: int) -> void:
	_send_housekeeper()


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


## Housekeeper makes the same kind of round trip per dirtied room. Same
## cut-short-and-restart limitation as the bellhop above.
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
## off on a cleaning trip -- this view is only an abstract strip (Entrance/
## Reception/Elevator), not a real hotel map, so "wanders around fixing
## things" is represented as a small idle bounce in place rather than actual
## pathing to arbitrary spots.
func _on_housekeeper_idle_tick() -> void:
	if _housekeeper_tween != null and _housekeeper_tween.is_valid():
		return
	var nudge := create_tween()
	nudge.tween_property(_housekeeper, "position:y", HOUSEKEEPER_Y - 6.0, 0.25)
	nudge.tween_property(_housekeeper, "position:y", HOUSEKEEPER_Y, 0.25)
