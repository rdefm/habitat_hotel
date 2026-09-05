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
## ease_to_fit_all() (wired to a HUD button by main_screen.gd). Ticket 07
## adds the three Station posts and every Staffer standing at one or in the
## staff nook; interior bay content (guests, Build Slots, the elevator) is
## still later tickets' job.

const BuildingLayout = preload("res://sim/building_layout.gd")
const CharacterSprite = preload("res://ui/character_sprite.gd")
const StafferActor = preload("res://ui/staffer_actor.gd")
const Station = preload("res://sim/station.gd")

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

## How far the pointer must move between press and release, in world units,
## before a Staffer pick-up counts as a drag rather than a tap -- below this
## it's a tap (opens the detail popup), at or above it it's a drag (drop
## against a Station post to (re)assign, or a no-op if released elsewhere).
const STAFFER_DRAG_THRESHOLD := 6.0

## Generous drop-target box around a Station post's single anchor point
## (larger than the post's own STATION_PROP_SIZE render footprint) so a
## dropped Staffer doesn't have to land pixel-perfect on the prop.
const STATION_POST_HIT_SIZE := Vector2(60.0, 60.0)

## Emitted whenever a Staffer is tapped (a press/release with no drag) so
## main_screen can open their existing Skill/Trait detail popup -- same
## contract as ui/station_panel.gd's retired staffer_tapped signal.
signal staffer_tapped(staffer_id: String)

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

## Ticket 07: Station posts (station_id -> world Rect2 drop-target) and
## Staffer actors (staffer_id -> StafferActor), rebuilt whenever
## GameState.stations changes -- see _process()'s signature check below.
var _station_post_rects: Dictionary = {}
var _staffer_actors: Dictionary = {}
var _cached_stations_signature := ""

## Non-empty while a Staffer is picked up (press landed on a StafferActor's
## hit_rect()) -- the id being dragged, its press-time world position (for
## the tap-vs-drag threshold), and a semi-transparent ghost sprite
## following the pointer. Mutually exclusive with _dragging (camera pan):
## a press either starts one or the other, never both.
var _drag_staffer_id := ""
var _drag_start_world := Vector2.ZERO
var _drag_preview: CharacterSprite = null


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
		return

	## Reception/Terrace never move when a Room floor unlocks (they're
	## always floors()'s first two entries), so a Station (re)assignment --
	## the only thing that changes who stands at a post/nook -- only needs
	## to rebuild the Staffer actors, not the whole shell above.
	var stations_signature := str(GameState.stations)
	if stations_signature != _cached_stations_signature:
		_cached_stations_signature = stations_signature
		_rebuild_staffers(BuildingLayout.floors(GameState.rooms, GameState.stars))


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

	_rebuild_station_posts(floors)
	_rebuild_staffers(floors)
	_cached_stations_signature = str(GameState.stations)

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


## --- Station posts and Staffer placement (ticket 07) ---
##
## Each Station is a physical post: a CharacterSprite rendering
## resolve_station_prop()'s prop/placeholder at the anchor
## resolve_station_post_anchor() names (front_desk, supply_closet, or the
## Terrace's kitchen_pass -- ADR-0010 unchanged). A Station's staffing
## level is meant to be readable from who's standing there, so no tap
## behaviour lives on the post itself here -- only the drop-target rect
## _unhandled_input checks a Staffer drag's release against.
func _rebuild_station_posts(floors: Array) -> void:
	_station_post_rects.clear()
	for station_id in Station.IDS:
		var post: Vector2 = BuildingLayout.resolve_station_post_anchor(floors, station_id)
		var prop := CharacterSprite.new()
		_building.add_child(prop)
		prop.configure(BuildingLayout.resolve_station_prop(station_id))
		prop.position = post
		_station_post_rects[station_id] = Rect2(post - STATION_POST_HIT_SIZE / 2.0, STATION_POST_HIT_SIZE)


## Every Staffer, standing at their Station's post if assigned or the staff
## nook if not (sim/building_layout.gd's staffer_placements(), ticket 07)
## -- replaces ticket 06's hardcoded _spawn_manny() with the same
## resolve_character_sprite("staffer", id, "idle") path for every Staffer,
## Manny included: he has no idle sheet, so he now renders his placeholder
## like anyone else's rest state would, rather than being special-cased
## into his walk-cycle demo -- nothing yet drives a "working" state (that's
## tickets 08/13's Job travel). Called on structural rebuilds and whenever
## GameState.stations changes (see _process()), never mid-drag: the
## Staffer actually being dragged is only ever moved by our own
## Sim.assign_staffer() call at drop, which happens after the drag has
## already ended.
func _rebuild_staffers(floors: Array) -> void:
	for actor in _staffer_actors.values():
		actor.queue_free()
	_staffer_actors.clear()

	var placements := BuildingLayout.staffer_placements(GameState.stations, GameState.staffers.keys())
	for staffer_id in placements.keys():
		var point: Vector2 = BuildingLayout.resolve_staffer_point(floors, placements[staffer_id])
		var actor := StafferActor.new()
		_building.add_child(actor)
		actor.configure(staffer_id)
		actor.position = point
		_staffer_actors[staffer_id] = actor


## --- Staffer tap/drag (ticket 07) ---
##
## Hand-rolled against world-space hit rects rather than Godot's Control-
## only _get_drag_data()/_can_drop_data() API (spec.md: "a thin invisible
## Control in front of the art, or an Area2D with hand-rolled drag,
## whichever is cheaper") -- posts and actors already know their own world
## position, so comparing a press/release point against their rects is
## cheaper here than re-deriving screen-space Control rects every frame,
## which is exactly the pattern this rewrite replaces (spec.md's Problem
## Statement).

func _staffer_at(world_pos: Vector2) -> String:
	for staffer_id in _staffer_actors.keys():
		var actor: StafferActor = _staffer_actors[staffer_id]
		if actor.hit_rect().has_point(world_pos):
			return staffer_id
	return ""


func _station_post_at(world_pos: Vector2) -> String:
	for station_id in _station_post_rects.keys():
		if _station_post_rects[station_id].has_point(world_pos):
			return station_id
	return ""


func _begin_staffer_drag(staffer_id: String, world_pos: Vector2) -> void:
	_drag_staffer_id = staffer_id
	_drag_start_world = world_pos
	_drag_preview = CharacterSprite.new()
	add_child(_drag_preview)
	_drag_preview.configure(BuildingLayout.resolve_character_sprite("staffer", staffer_id, "idle"))
	_drag_preview.modulate.a = 0.7
	_drag_preview.position = world_pos


func _update_staffer_drag(world_pos: Vector2) -> void:
	if _drag_preview != null:
		_drag_preview.position = world_pos


## Ends the in-progress Staffer drag/tap: assigns via the existing
## Sim.assign_staffer() path (the same reassignment/interruption semantics
## ui/station_card.gd's drop handling already used) if the release moved
## past the drag threshold and landed on a post, emits staffer_tapped if it
## didn't move (a tap), and otherwise leaves the Staffer where they were --
## no explicit "unassign" gesture exists, matching the old Control view.
func _end_staffer_drag(world_pos: Vector2) -> void:
	var staffer_id := _drag_staffer_id
	var moved := world_pos.distance_to(_drag_start_world) >= STAFFER_DRAG_THRESHOLD

	_drag_staffer_id = ""
	if _drag_preview != null:
		_drag_preview.queue_free()
		_drag_preview = null

	if moved:
		var station_id := _station_post_at(world_pos)
		if station_id != "":
			Sim.assign_staffer(staffer_id, station_id)
	else:
		staffer_tapped.emit(staffer_id)


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
			if event.pressed:
				_on_press(get_global_mouse_position())
			else:
				_on_release(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		if _drag_staffer_id != "":
			_update_staffer_drag(get_global_mouse_position())
		elif _dragging:
			_pan_by(event.relative)
	elif event is InputEventMagnifyGesture:
		## factor > 1 is a pinch-out (fingers spreading -- "zoom in" intent),
		## which under this project's confirmed zoom convention means
		## multiplying zoom UP, not down.
		_zoom_by(event.factor)
	elif event is InputEventScreenTouch:
		if event.pressed:
			_on_press(get_global_mouse_position())
		else:
			_on_release(get_global_mouse_position())
	elif event is InputEventScreenDrag:
		if _drag_staffer_id != "":
			_update_staffer_drag(get_global_mouse_position())
		else:
			_pan_by(event.relative)


## Shared press handler for a mouse-left-button or touch-down event: if it
## landed on a Staffer, that starts a Staffer drag/tap instead of a camera
## pan (see the header comment above _staffer_at()).
func _on_press(world_pos: Vector2) -> void:
	var staffer_id := _staffer_at(world_pos)
	if staffer_id != "":
		_begin_staffer_drag(staffer_id, world_pos)
	else:
		_dragging = true


func _on_release(world_pos: Vector2) -> void:
	if _drag_staffer_id != "":
		_end_staffer_drag(world_pos)
	else:
		_dragging = false


func _zoom_by(factor: float) -> void:
	var current_zoom: float = _camera.zoom.x
	var new_zoom: float = clampf(current_zoom * factor, _fit_all_zoom, MAX_ZOOM)
	_camera.zoom = Vector2(new_zoom, new_zoom)


func _pan_by(screen_delta: Vector2) -> void:
	_camera.position -= screen_delta / _camera.zoom
