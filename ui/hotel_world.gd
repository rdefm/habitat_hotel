class_name HotelWorld
extends Node2D

## The Node2D building world (ticket 04, ADR-0020) that replaces
## ui/hotel_view.gd's Control/ScrollContainer stack behind main_screen.gd's
## development toggle. Composes ticket 03's sliced shell art bottom-to-top
## per sim/building_layout.gd's pure floor list -- the only thing this node
## derives on its own is *how* to draw what that module already decided.
##
## Framed by a Camera2D that defaults to fit-all, pans on drag, zooms on
## scroll/pinch within clamped bounds, and can be eased back to fit-all via
## ease_to_fit_all() (wired to a HUD button by main_screen.gd). Interior bay
## content (guests, staff, Build Slots, the elevator) is later tickets'
## job -- this ticket only draws the shell, the floor signs, and the sky.

const BuildingLayout = preload("res://sim/building_layout.gd")
const CharacterSprite = preload("res://ui/character_sprite.gd")

## Most-zoomed-in Camera2D.zoom value this world allows. Confirmed
## empirically against this project's canvas_items+expand stretch setup
## (project.godot) -- a fixed-size probe sprite measured exactly 2x the
## screen pixels at zoom=2 vs zoom=1 -- that a LARGER zoom is MORE
## magnified (shows less world), the opposite of the stretch-agnostic
## convention some Godot docs describe. The most-zoomed-OUT end of the
## clamp is fit-all's own (smaller) zoom, recomputed whenever the floor
## stack changes, since there's nothing left to show past that.
const MAX_ZOOM := 3.0
const ZOOM_STEP := 1.1
const FIT_ALL_EASE_SECONDS := 0.4

## Sky tint per Clock.Phase (autoload/clock.gd), keyed by the enum's plain
## int value (MORNING=0, MIDDAY=1, EVENING=2, NIGHT=3) rather than the enum
## type itself, since Clock has no class_name to reference statically.
## Interpolated continuously against Clock.tick_in_day in _update_sky_tint()
## so Night's short ~5-real-second window (Clock: 20 of its 240 ticks at
## 1x) reads as a genuine fade, not a snap.
const SKY_COLORS := {
	0: Color(0.98, 0.78, 0.62), # Morning
	1: Color(0.55, 0.78, 0.95), # Midday
	2: Color(0.85, 0.45, 0.45), # Evening
	3: Color(0.07, 0.08, 0.2), # Night
}

var _camera: Camera2D
var _building: Node2D
var _sky: ColorRect

var _cached_floor_count := -1
var _fit_all_zoom := 1.0

var _dragging := false


func _ready() -> void:
	_sky = ColorRect.new()
	_sky.size = Vector2(6000, 6000)
	_sky.position = Vector2(-3000, -5500)
	_sky.z_index = -10
	_sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sky)

	_building = Node2D.new()
	add_child(_building)

	_camera = Camera2D.new()
	add_child(_camera)
	## make_current() rather than the `current` property setter: the latter
	## raises "Invalid assignment of property... on a base object of type
	## 'Camera2D'" under --headless's dummy rendering driver (reproduced
	## directly, unrelated to this scene) -- make_current() achieves the
	## same thing and works under both.
	_camera.make_current()

	_rebuild_building()
	ease_to_fit_all(0.0)

	set_process(true)
	set_process_unhandled_input(true)


func _process(_delta: float) -> void:
	_update_sky_tint()

	var floor_count := BuildingLayout.unlocked_room_type_ids_ascending(GameState.rooms, GameState.stars).size()
	if floor_count != _cached_floor_count:
		_cached_floor_count = floor_count
		_rebuild_building()
		ease_to_fit_all()


## --- Building composition ---

func _rebuild_building() -> void:
	for child in _building.get_children():
		child.queue_free()

	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)

	var plinth := _make_sprite("ground_plinth.png")
	plinth.position = Vector2(0, -BuildingLayout.PLINTH_HEIGHT)
	_building.add_child(plinth)

	for i in range(floors.size()):
		_add_floor_band(floors, i)

	var roof_bottom_y: float = BuildingLayout.floor_bottom_y(floors, floors.size())
	var roof := _make_sprite("roofline_cap.png")
	roof.position = Vector2(0, roof_bottom_y - BuildingLayout.ROOF_HEIGHT)
	_building.add_child(roof)

	_spawn_manny(floors)

	_fit_all_zoom = _fit_zoom(BuildingLayout.fit_all_bounds(floors))


func _add_floor_band(floors: Array, i: int) -> void:
	var f: Dictionary = floors[i]
	var bottom_y: float = BuildingLayout.floor_bottom_y(floors, i)
	var top_y: float = bottom_y - float(f["height"])

	if f["band_variant"] == "full":
		var sprite := _make_sprite(_shell_file_for_full_band(f))
		sprite.position = Vector2(0, top_y)
		_building.add_child(sprite)
	else:
		_add_tiled_room_band(top_y, float(f["height"]), f["interior"])

	_add_floor_sign(String(f["sign_text"]), top_y)


## Reception and Terrace always use their own fixed full-width band; a
## "full" Room floor is one of ticket 05's three painted types, whose
## specific file BuildingLayout.resolve_room_interior() already picked --
## the renderer just load()s whatever path it's handed, per every slot in
## this file, rather than deciding anything on its own.
func _shell_file_for_full_band(f: Dictionary) -> String:
	if f["kind"] == "reception":
		return "lobby_band.png"
	if f["kind"] == "terrace":
		return "terrace_band.png"
	return String(f["interior"]["file"])


## A Room floor with no painted interior of its own (ticket 05's fallback
## for cozy_nook/cavern_suite/tundra_hall, or any Room type outside
## BuildingLayout.ROOM_TYPE_INTERIOR_FILE): the reusable
## frame_column_left/right + elevator_shaft_segment tiles from ticket 03,
## flanking a placeholder tinted and labelled per Room type (rather than
## ticket 04's single neutral tint) at the exact x-offsets ticket 03's cut
## documents (column 0-71, shaft 71-168, interior 168-501, column 501-572
## of the 572-wide row) -- identical footprint to a painted interior at
## the same height, per the contract's fallback rule.
func _add_tiled_room_band(top_y: float, height: float, interior: Dictionary) -> void:
	var left := _make_sprite("frame_column_left.png")
	left.position = Vector2(0, top_y)
	_building.add_child(left)

	var shaft := _make_sprite("elevator_shaft_segment.png")
	shaft.position = Vector2(BuildingLayout.COLUMN_WIDTH, top_y)
	_building.add_child(shaft)

	var placeholder := ColorRect.new()
	placeholder.color = interior["tint"]
	placeholder.size = Vector2(BuildingLayout.INTERIOR_WIDTH, height)
	placeholder.position = Vector2(BuildingLayout.COLUMN_WIDTH + BuildingLayout.SHAFT_WIDTH, top_y)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_building.add_child(placeholder)

	var right := _make_sprite("frame_column_right.png")
	right.position = Vector2(BuildingLayout.COLUMN_WIDTH + BuildingLayout.SHAFT_WIDTH + BuildingLayout.INTERIOR_WIDTH, top_y)
	_building.add_child(right)

	_add_placeholder_label(String(interior["label"]), top_y, height)


## The temporary label ticket 05's contract calls for on a fallback
## interior -- disappears the moment that Room type gets a real painted
## slot, same as the contract's general fallback text.
func _add_placeholder_label(text: String, top_y: float, height: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = Vector2(BuildingLayout.COLUMN_WIDTH + BuildingLayout.SHAFT_WIDTH + 10.0, top_y + height / 2.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_building.add_child(label)


func _add_floor_sign(sign_text: String, top_y: float) -> void:
	var label := Label.new()
	label.text = sign_text
	label.position = Vector2(10, top_y + 6)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	_building.add_child(label)


## --- Manny (ticket 06, ADR-0015) ---
##
## Manny is the asset contract's reference implementation: his existing
## walk sheet loads through resolve_character_sprite() exactly like any
## other Staffer's would, proving the same resolver that falls back to a
## placeholder for everyone else also renders a real animated sprite at
## its contract footprint. "Standing somewhere in the world and moving"
## (the ticket's own words) is his animated walk-cycle playing in place,
## not a scripted patrol -- there is no wander behaviour and no ambient
## behaviour scheduler (spec.md, Out of Scope). Placed at Reception's
## staff nook, where Station.gd's Staff Pool -- Manny's real starting
## state -- already loiters; real Station-post assignment and its
## rendering, which would be what actually moves him, is ticket 07's job.
## His "working" (sweep) alias resolves and renders through this exact
## same path, verified directly rather than reproduced here: there's no
## real Job driving which state should show until ticket 07/08 exist.
func _spawn_manny(floors: Array) -> void:
	var nook: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "staff_nook")

	var resolved := BuildingLayout.resolve_character_sprite("staffer", "manny", "walk")
	var manny := CharacterSprite.new()
	_building.add_child(manny)
	manny.configure(resolved)
	manny.position = nook


func _make_sprite(filename: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(BuildingLayout.SHELL_DIR + filename)
	sprite.centered = false
	return sprite


## --- Sky ---

func _update_sky_tint() -> void:
	var current: int = int(Clock.current_phase)
	var next: int = (current + 1) % 4
	var this_start := _phase_start_tick(current)
	var next_start: int = Clock.TICKS_PER_DAY + 1 if next == 0 else _phase_start_tick(next)
	var span: float = maxf(1.0, float(next_start - this_start))
	var progress: float = clampf(float(Clock.tick_in_day - this_start) / span, 0.0, 1.0)
	_sky.color = SKY_COLORS[current].lerp(SKY_COLORS[next], progress)


func _phase_start_tick(phase_value: int) -> int:
	for pair in Clock.PHASE_START_TICKS:
		if int(pair[0]) == phase_value:
			return int(pair[1])
	return 1


## --- Camera: fit-all, zoom, pan ---

## The largest Camera2D.zoom that still contains all of `bounds` within the
## viewport -- i.e. the tightest fit-all framing, touching the constraining
## axis and leaving margin on the other. See MAX_ZOOM's comment for the
## empirically-confirmed zoom convention this relies on: viewport_size and
## bounds are in the same (logical, canvas_items-stretch) units
## get_viewport_rect() and every world position in this scene already use,
## so no separate physical-pixel conversion is needed here.
func _fit_zoom(bounds: Rect2) -> float:
	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return 1.0
	return minf(viewport_size.x / bounds.size.x, viewport_size.y / bounds.size.y)


## Eases the camera back to framing the whole building. Called on ready, on
## every floor unlock (bounds change), and from a HUD "fit all" control.
func ease_to_fit_all(duration: float = FIT_ALL_EASE_SECONDS) -> void:
	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)
	var bounds := BuildingLayout.fit_all_bounds(floors)
	_fit_all_zoom = _fit_zoom(bounds)
	var target_position: Vector2 = bounds.position + bounds.size / 2.0

	if duration <= 0.0 or _camera == null:
		if _camera != null:
			_camera.global_position = target_position
			_camera.zoom = Vector2(_fit_all_zoom, _fit_all_zoom)
		return

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_camera, "global_position", target_position, duration)
	tween.tween_property(_camera, "zoom", Vector2(_fit_all_zoom, _fit_all_zoom), duration)


func _unhandled_input(event: InputEvent) -> void:
	if _camera == null:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / ZOOM_STEP)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		_pan_by(event.relative)
	elif event is InputEventMagnifyGesture:
		## factor > 1 is a pinch-out (fingers spreading -- "zoom in" intent),
		## which under this project's confirmed zoom convention means
		## multiplying zoom UP, not down.
		_zoom_by(event.factor)
	elif event is InputEventScreenDrag:
		_pan_by(event.relative)


func _zoom_by(factor: float) -> void:
	var current_zoom: float = _camera.zoom.x
	var new_zoom: float = clampf(current_zoom * factor, _fit_all_zoom, MAX_ZOOM)
	_camera.zoom = Vector2(new_zoom, new_zoom)


func _pan_by(screen_delta: Vector2) -> void:
	_camera.position -= screen_delta / _camera.zoom
