class_name ToastLayer
extends Control

## Toast notifications (ticket 08, ADR-0016): replaces main_screen.gd's
## scrolling day-log ticker with brief, auto-dismissing toast nodes anchored
## near the event's real spatial location -- Reception for day-summary/
## forecast events, the specific Room cell for a checkout's review. Lives as
## a screen-space overlay sibling *above* HotelView (mouse_filter IGNORE,
## same reasoning as ui/room_occupancy_layer.gd's class doc: never intercept
## a tap/drag meant for a RoomCellButton beneath it) rather than inside any
## one panel, so a HotelPanel.refresh() rebuild can't free a toast out from
## under itself.
##
## Toast text carries the same information main_screen.gd's old
## _on_day_summary/_on_review_posted/_on_forecast_ready handlers used to
## append to the day log, minus the BBCode markup that only made sense
## inside the old RichTextLabel (a toast Label colors its whole line via
## Color instead of highlighting one colored substring). review_posted now
## also carries the checkout's room_type_id/instance_id (sim_controller.gd's
## _checkout_guest()) so its toast can anchor to that Room's live cell
## instead of falling back to Reception.
##
## Multiple toasts anchored at the same spot (e.g. several checkouts'
## reviews landing on the same Room floor, or a day-summary and a forecast
## both anchored at Reception) stack vertically in arrival order rather than
## overlapping -- _stacks tracks each anchor key's live toast list so a new
## toast can pack itself in above the others still visible there, and
## _reposition_stack() re-packs a stack's survivors every frame so a
## dismissed toast's gap closes up immediately.

const DemandFormat = preload("res://ui/demand_format.gd")
const HotelPanel = preload("res://ui/hotel_panel.gd")
const ReceptionPanel = preload("res://ui/reception_panel.gd")
const MatchHint = preload("res://sim/match_hint.gd")

const TOAST_WIDTH := 260.0
const TOAST_GAP := 6.0
const VISIBLE_DURATION := 3.5
const FADE_DURATION := 0.4
const RECEPTION_ANCHOR_KEY := "reception"

## Set by main_screen before/after this node enters the tree -- read lazily
## (find_room_cell()/get_global_rect() calls) rather than cached, so a later
## HotelPanel/ReceptionPanel rebuild is always reflected, matching
## ui/room_occupancy_layer.gd's own convention.
var hotel_panel: HotelPanel
var reception_panel: ReceptionPanel

## anchor_key -> Array[Control], oldest first, packed upward from the anchor
## point.
var _stacks: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	EventBus.day_summary.connect(_on_day_summary)
	EventBus.review_posted.connect(_on_review_posted)
	EventBus.forecast_ready.connect(_on_forecast_ready)
	set_process(true)


func _process(_delta: float) -> void:
	for key in _stacks.keys():
		_reposition_stack(key)


func _on_day_summary(summary: Dictionary) -> void:
	var turned_away: int = summary["walked_away_mismatch"] + summary["walked_away_full"] + summary["walked_away_too_expensive"]
	var text := "Day %d -- cash %+d, occupancy %.0f%%, %d checkout(s), %d arrival(s), %d turned away" % [
		summary["day"], summary["cash_delta"], summary["occupancy_rate"] * 100.0, summary["checkouts"],
		summary["arrivals"], turned_away,
	]
	if turned_away > 0:
		text += "\nturned away: %s" % DemandFormat.summarize_counts(summary["turned_away_species"], GameState.species)
	_spawn(RECEPTION_ANCHOR_KEY, text, Color(0.85, 0.85, 1.0))


func _on_review_posted(review: Dictionary) -> void:
	var color: Color = {"positive": Color(0.6, 1.0, 0.6), "negative": Color(1.0, 0.6, 0.6)}.get(review["review"], Color(0.85, 0.85, 0.85))
	var guest_name: String = review.get("guest_name", "") if review.get("guest_name", "") else "Guest"
	var text := "%s the %s (%s, %+d cash) -- \"%s\"" % [
		guest_name, review["species_name"], review["review"], review["revenue"], review["flavor_line"],
	]
	var key := _room_anchor_key(String(review.get("room_type_id", "")), int(review.get("instance_id", -1)))
	_spawn(key, text, color)


func _on_forecast_ready(for_day: int, arrivals: Array) -> void:
	var text := "Forecast for Day %d: %s" % [for_day, DemandFormat.summarize_arrivals(arrivals, GameState.species)]
	_spawn(RECEPTION_ANCHOR_KEY, text, Color(0.6, 0.9, 1.0))


## --- Spawning/dismissal ---

func _spawn(anchor_key: String, text: String, text_color: Color) -> void:
	var toast := _make_toast(text, text_color)
	toast.modulate.a = 0.0
	add_child(toast)

	var stack: Array = _stacks.get(anchor_key, [])
	stack.append(toast)
	_stacks[anchor_key] = stack
	_reposition_stack(anchor_key)

	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, FADE_DURATION)
	tween.tween_interval(VISIBLE_DURATION)
	tween.tween_property(toast, "modulate:a", 0.0, FADE_DURATION)
	tween.tween_callback(_dismiss.bind(anchor_key, toast))


func _dismiss(anchor_key: String, toast: Control) -> void:
	var stack: Array = _stacks.get(anchor_key, [])
	stack.erase(toast)
	if stack.is_empty():
		_stacks.erase(anchor_key)
	else:
		_stacks[anchor_key] = stack
	toast.queue_free()


func _reposition_stack(anchor_key: String) -> void:
	var stack: Array = _stacks.get(anchor_key, [])
	if stack.is_empty():
		return
	var anchor := _anchor_position(anchor_key)
	var y := anchor.y
	for toast in stack:
		if not is_instance_valid(toast):
			continue
		y -= toast.size.y + TOAST_GAP
		toast.position = Vector2(anchor.x - TOAST_WIDTH / 2.0, y)


## --- Anchors ---

## Reuses MatchHint.room_key()'s own room_type_id+instance_id key format
## (room_occupancy_layer.gd's _room_key() does the same) rather than
## inventing a second one -- prefixed so it can't collide with
## RECEPTION_ANCHOR_KEY.
func _room_anchor_key(room_type_id: String, instance_id: int) -> String:
	if room_type_id == "" or instance_id < 0:
		return RECEPTION_ANCHOR_KEY # defensive only -- review_posted always carries these today
	return "room|" + MatchHint.room_key({"room_type_id": room_type_id, "instance_id": instance_id})


## Falls back to Reception whenever a Room-cell anchor can't be resolved --
## the Room's floor hasn't been unlocked-scrolled into view, or a
## HotelPanel.refresh() rebuild hasn't recreated the cell for this frame
## yet -- so a toast is never simply left un-positioned.
func _anchor_position(anchor_key: String) -> Vector2:
	if anchor_key != RECEPTION_ANCHOR_KEY and hotel_panel != null:
		var room_key := anchor_key.trim_prefix("room|")
		var parts := room_key.split("#")
		if parts.size() == 2:
			var cell := hotel_panel.find_room_cell(parts[0], int(parts[1]))
			if cell != null:
				return _to_local(cell.get_global_rect().get_center())
	return _reception_anchor()


func _reception_anchor() -> Vector2:
	if reception_panel == null:
		return Vector2.ZERO
	return _to_local(reception_panel.get_global_rect().get_center())


func _to_local(global_pos: Vector2) -> Vector2:
	return global_pos - global_position


## --- Toast node ---

func _make_toast(text: String, text_color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(TOAST_WIDTH, 0)
	panel.size = Vector2(TOAST_WIDTH, 0)

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.14, 0.92)
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", box)

	var label := Label.new()
	label.text = text
	label.modulate = text_color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
