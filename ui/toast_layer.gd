class_name ToastLayer
extends Control

## Toast notifications (ticket 08, ADR-0016; ticket 15, ADR-0020): brief,
## auto-dismissing toast nodes anchored near the event's real spatial
## location -- Reception for day-summary/forecast events, the Terrace for
## dining events, the specific Room bay for a checkout's review. Lives as a
## screen-space overlay in main_screen.gd's HUD CanvasLayer (mouse_filter
## IGNORE, same reasoning as ui/room_occupancy_layer.gd's class doc: never
## intercept a tap/drag meant for whatever's beneath it) rather than inside
## any one panel, so a rebuild elsewhere can't free a toast out from under
## itself.
##
## Two coexisting anchor systems, one per main_screen.USE_HOTEL_WORLD mode --
## spec.md's migration plan only retires "the Control-space parts of
## toast_layer.gd" (not the whole file) in ticket 17, so both stay wired
## until then:
##  - Control mode (`hotel_panel`/`reception_panel` set): the original
##    ticket-08 behaviour, re-deriving each anchor's on-screen rect from a
##    live Control every frame (_anchor_position()/_reception_anchor()).
##  - World mode (`hotel_world` set, ticket 15): an anchor is resolved ONCE,
##    as a WORLD position (sim/building_layout.gd's anchor registry) rather
##    than a Control rect -- floors never move once placed (spec.md: "a
##    newly unlocked Room type stacks on top and never renumbers the floors
##    below"), so there's nothing to re-derive. What changes every frame is
##    only the camera, so each frame this projects that fixed world anchor
##    through HotelWorld.world_to_screen() (ADR-0020: "a toast is a node
##    parented to its anchor... now a world position projected through the
##    camera"). When the projected point falls outside the camera's current
##    framing, every toast at that anchor hides and a single tappable arrow
##    marker appears clamped to the nearest screen edge, pointing back at the
##    anchor -- tapping it calls HotelWorld.pan_to_world_point() (spec.md
##    stories 51/52).
##
## Toast text carries the same information main_screen.gd's old
## _on_day_summary/_on_review_posted/_on_forecast_ready handlers used to
## append to the retired day-log ticker, minus the BBCode markup that only
## made sense inside the old RichTextLabel (a toast Label colors its whole
## line via Color instead of highlighting one colored substring). Ticket 15
## adds the Terrace's own dining events (EventBus.dining_guest_served/
## dining_guest_walked_away), which never had a toast of their own before --
## no day-log line existed for them either, so nothing regresses in Control
## mode by wiring them there too. review_posted carries the checkout's
## room_type_id/instance_id (sim_controller.gd's _checkout_guest()) so its
## toast can anchor to that Room's live cell/bay instead of falling back to
## Reception.
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
const HotelWorld = preload("res://ui/hotel_world.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")
const MatchHint = preload("res://sim/match_hint.gd")

const TOAST_WIDTH := 260.0
const TOAST_GAP := 6.0
const VISIBLE_DURATION := 3.5
const FADE_DURATION := 0.4
const RECEPTION_ANCHOR_KEY := "reception"
const TERRACE_ANCHOR_KEY := "terrace"

## How far inside the viewport's visible content (below the HUD strip) an
## anchor's projected screen point must stay before it's considered "in
## framing" -- world mode only. Also the margin an edge marker is clamped
## inside of, so it never sits flush against the true screen edge.
const EDGE_MARGIN := 28.0
const EDGE_MARKER_SIZE := Vector2(32.0, 32.0)

## Set by main_screen before/after this node enters the tree -- read lazily
## (find_room_cell()/get_global_rect() calls) rather than cached, so a later
## HotelPanel/ReceptionPanel rebuild is always reflected, matching
## ui/room_occupancy_layer.gd's own convention. Control mode only.
var hotel_panel: HotelPanel
var reception_panel: ReceptionPanel

## Set by main_screen for world mode (ticket 15) instead of the two above.
## Exactly one of this and hotel_panel/reception_panel is set for the
## lifetime of this node -- main_screen picks one at construction per
## USE_HOTEL_WORLD, mirroring every other dual-mode view piece in this repo.
var hotel_world: HotelWorld

## anchor_key -> Array[Control], oldest first, packed upward from the anchor
## point.
var _stacks: Dictionary = {}

## World mode only: anchor_key -> Vector2, the anchor's fixed world position,
## resolved once when its first live toast spawns (see the class doc: a
## floor's anchors never move once placed, so there's nothing to refresh).
var _world_anchor_positions: Dictionary = {}

## World mode only: anchor_key -> Button, the tappable arrow marker shown
## while that anchor's toasts are all hidden off current framing. Created
## lazily on first need, hidden (not freed) between uses, and freed only
## when its whole stack empties (_dismiss()).
var _edge_markers: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	## A plain Control added directly under a CanvasLayer (world mode's
	## hud_layer, main_screen.gd) can silently resolve to a zero-size rect
	## even with PRESET_FULL_RECT -- the preset's own offset defaults don't
	## reliably fill the viewport there (docs/agents/godot-ai.md's own
	## documented gotcha). Every child here is positioned with an explicit
	## Vector2 rather than anchored relative to this rect, so it's harmless
	## today, but pin the offsets explicitly anyway rather than rely on that.
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	EventBus.day_summary.connect(_on_day_summary)
	EventBus.review_posted.connect(_on_review_posted)
	EventBus.forecast_ready.connect(_on_forecast_ready)
	EventBus.dining_guest_served.connect(_on_dining_guest_served)
	EventBus.dining_guest_walked_away.connect(_on_dining_guest_walked_away)
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


## Ticket 15: the Terrace's own dining events never had a toast of their own
## before this ticket -- no retired day-log line covered them either, so
## nothing regresses by adding one now, in both anchor modes alike.
func _on_dining_guest_served(guest_name: String, species_id: String, review: String, _satisfaction: float) -> void:
	var color: Color = {"positive": Color(0.6, 1.0, 0.6), "negative": Color(1.0, 0.6, 0.6)}.get(review, Color(0.85, 0.85, 0.85))
	var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
	var text := "%s the %s dined at the Terrace -- %s" % [guest_name, species_name, review]
	_spawn(TERRACE_ANCHOR_KEY, text, color)


func _on_dining_guest_walked_away(guest_name: String, species_id: String) -> void:
	var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
	var text := "%s the %s walked away from the Terrace" % [guest_name, species_name]
	_spawn(TERRACE_ANCHOR_KEY, text, Color(1.0, 0.6, 0.6))


## --- Spawning/dismissal ---

func _spawn(anchor_key: String, text: String, text_color: Color) -> void:
	var toast := _make_toast(text, text_color)
	toast.modulate.a = 0.0
	add_child(toast)

	var stack: Array = _stacks.get(anchor_key, [])
	stack.append(toast)
	_stacks[anchor_key] = stack

	if hotel_world != null:
		_world_anchor_positions[anchor_key] = _resolve_world_anchor(anchor_key)

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
		_world_anchor_positions.erase(anchor_key)
		var marker: Button = _edge_markers.get(anchor_key)
		if marker != null:
			marker.queue_free()
			_edge_markers.erase(anchor_key)
	else:
		_stacks[anchor_key] = stack
	toast.queue_free()


func _reposition_stack(anchor_key: String) -> void:
	var stack: Array = _stacks.get(anchor_key, [])
	if stack.is_empty():
		return
	if hotel_world != null:
		_reposition_stack_world(anchor_key, stack)
	else:
		_reposition_stack_control(anchor_key, stack)


func _reposition_stack_control(anchor_key: String, stack: Array) -> void:
	var anchor := _anchor_position(anchor_key)
	var y := anchor.y
	for toast in stack:
		if not is_instance_valid(toast):
			continue
		toast.visible = true
		y -= toast.size.y + TOAST_GAP
		toast.position = Vector2(anchor.x - TOAST_WIDTH / 2.0, y)


## World mode (ticket 15): projects the anchor's fixed world position through
## the camera every frame (HotelWorld.world_to_screen()) rather than
## re-deriving a Control rect. When the projected point still falls within
## the visible content rect (the viewport, minus the HUD strip and
## EDGE_MARGIN on every side), every toast in the stack renders normally,
## packed upward from that screen point exactly like Control mode. Otherwise
## every toast hides and a single arrow marker appears clamped to the
## nearest edge of that same rect, rotated to point back at the true anchor.
func _reposition_stack_world(anchor_key: String, stack: Array) -> void:
	var world_anchor: Vector2 = _world_anchor_positions.get(anchor_key, Vector2.ZERO)
	var screen_anchor := hotel_world.world_to_screen(world_anchor)
	var content_rect := _visible_content_rect().grow(-EDGE_MARGIN)

	if content_rect.has_point(screen_anchor):
		_hide_edge_marker(anchor_key)
		var y := screen_anchor.y
		for toast in stack:
			if not is_instance_valid(toast):
				continue
			toast.visible = true
			y -= toast.size.y + TOAST_GAP
			toast.position = Vector2(screen_anchor.x - TOAST_WIDTH / 2.0, y)
	else:
		for toast in stack:
			if is_instance_valid(toast):
				toast.visible = false
		_show_edge_marker(anchor_key, screen_anchor, content_rect)


func _visible_content_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	return Rect2(Vector2(0.0, hotel_world.hud_top_margin), Vector2(viewport_size.x, viewport_size.y - hotel_world.hud_top_margin))


## --- Anchors ---

## Reuses MatchHint.room_key()'s own room_type_id+instance_id key format
## (room_occupancy_layer.gd's _room_key() does the same) rather than
## inventing a second one -- prefixed so it can't collide with
## RECEPTION_ANCHOR_KEY/TERRACE_ANCHOR_KEY.
func _room_anchor_key(room_type_id: String, instance_id: int) -> String:
	if room_type_id == "" or instance_id < 0:
		return RECEPTION_ANCHOR_KEY # defensive only -- review_posted always carries these today
	return "room|" + MatchHint.room_key({"room_type_id": room_type_id, "instance_id": instance_id})


## Falls back to Reception whenever a Room-cell anchor can't be resolved --
## the Room's floor hasn't been unlocked-scrolled into view, or a
## HotelPanel.refresh() rebuild hasn't recreated the cell for this frame
## yet -- so a toast is never simply left un-positioned. Control mode only.
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


## World mode (ticket 15): resolves anchor_key into a WORLD position via
## sim/building_layout.gd's own anchor registry, the same one hotel_world.gd
## draws every Station post, Room bay, and the Terrace's signage from -- no
## anchor math is duplicated here. A Room bay's instance_id doubles as its
## bay index directly (BuildingLayout.room_bay_states(): a built bay's own
## instance_id IS its bay index, since bays fill in ascending instance_id
## order), matching hotel_world.gd's own bay rendering loop. Falls back to
## Reception's front_desk for a room anchor whose floor can't be resolved
## (defensive only, mirroring _anchor_position()'s Control-mode fallback) --
## a toast is never left un-positioned in either mode.
func _resolve_world_anchor(anchor_key: String) -> Vector2:
	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)

	if anchor_key == TERRACE_ANCHOR_KEY:
		return BuildingLayout.resolve_terrace_signage_rect(floors).get_center()

	if anchor_key.begins_with("room|"):
		var parts := anchor_key.trim_prefix("room|").split("#")
		if parts.size() == 2:
			var room_type_id: String = parts[0]
			var floor_index := BuildingLayout.floor_index_for_room_type(floors, room_type_id)
			if floor_index != -1:
				var bay_index := int(parts[1])
				var anchor_name := "bay_left" if bay_index == 0 else "bay_right"
				var rect: Rect2 = BuildingLayout.resolve_anchor(floors, floor_index, anchor_name)
				return rect.get_center()

	return BuildingLayout.resolve_anchor(floors, 0, "front_desk")


## --- Edge markers (ticket 15, spec.md stories 51/52) ---

func _hide_edge_marker(anchor_key: String) -> void:
	var marker: Button = _edge_markers.get(anchor_key)
	if marker != null:
		marker.visible = false


func _show_edge_marker(anchor_key: String, screen_anchor: Vector2, content_rect: Rect2) -> void:
	var clamped := screen_anchor.clamp(content_rect.position, content_rect.position + content_rect.size)

	var marker: Button = _edge_markers.get(anchor_key)
	if marker == null:
		marker = _make_edge_marker(anchor_key)
		add_child(marker)
		_edge_markers[anchor_key] = marker

	marker.visible = true
	marker.position = clamped - marker.size / 2.0
	## The glyph points right at rotation 0 -- angling toward the true
	## (unclamped) anchor from the clamped screen edge point is exactly the
	## direction a player needs to look/pan.
	var offset := screen_anchor - clamped
	if offset != Vector2.ZERO:
		marker.rotation = offset.angle()


func _make_edge_marker(anchor_key: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = EDGE_MARKER_SIZE
	button.size = EDGE_MARKER_SIZE
	button.pivot_offset = EDGE_MARKER_SIZE / 2.0
	button.focus_mode = Control.FOCUS_NONE
	button.text = "➤" # "➤", rotated per _show_edge_marker() to point at the anchor
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))

	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.1, 0.1, 0.14, 0.9)
	box.corner_radius_top_left = 16
	box.corner_radius_top_right = 16
	box.corner_radius_bottom_left = 16
	box.corner_radius_bottom_right = 16
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, box)

	button.pressed.connect(_on_edge_marker_pressed.bind(anchor_key))
	return button


func _on_edge_marker_pressed(anchor_key: String) -> void:
	if hotel_world == null:
		return
	hotel_world.pan_to_world_point(_world_anchor_positions.get(anchor_key, Vector2.ZERO))


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
