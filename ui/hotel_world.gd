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
## staff nook. Ticket 08 adds every Room floor's two bays -- a built Room,
## a Build Slot, or an empty shell, tappable via room_slot_tapped. Ticket 09
## adds the Terrace's signage (tappable via terrace_tapped) and every
## Walk-in Diner/Dining Party standing at the pass or the entrance queue.
## Ticket 10 adds every arriving Party standing in the lobby as one
## GuestActor per member, an always-visible mood face on every lobby guest
## and Terrace diner alike (souring as Patience decays), and a Needs bubble
## of Tag icons popped by tapping a waiting lobby guest. Ticket 11 makes
## that same tap-opened selection double as the seating gesture's first half
## (ADR-0001/0009): tapping a lobby guest then tapping a Room bay, or
## dragging a guest onto one, both seat the Party through the same
## party_seat_attempted signal, with the selected Party's green/amber/none
## Match hint glowing on every built bay (BuildingLayout.room_bay_match_hint(),
## itself a thin wrapper over the existing Sim.match_hint() -- no hint logic
## duplicated here). A guest drag also auto-pans the camera near the top/
## bottom screen edge, so a lobby-to-top-floor drag is reachable at any
## zoom. Ticket 12 adds the elevator journey: on EventBus.guest_seated a
## fresh actor idles at the front desk until Sim's checkin.delay_ticks
## countdown (room["checking_in"]) resolves, then walks to the shaft, rides
## to the Room's own floor, and walks into its bay -- see
## _on_guest_seated()/_begin_checkin_ride()'s header comments. A settled
## occupant then renders every rebuild via RoomOccupantActor, at fixed spots
## in its bay (BuildingLayout.room_occupant_placements()), sleeping with a
## Zz at Night. EventBus.guest_checked_out plays the exact reverse journey;
## EventBus.guest_turned_away walks every member of a lost Party's own
## lobby actors back out through the lobby, no elevator involved. Every
## journey is real-time-tweened and decoupled from Sim's own tick-driven
## timing (spec.md: "the animation never gates the simulation") -- the wait
## is polled against Sim's own flag rather than re-timed to match it, and a
## Room whose journey is still in flight is skipped by the ordinary
## occupant render pass so the two never show the guest twice. Ticket 13
## reuses this same elevator-ride machinery (_play_ride_legs()) for a
## Housekeeping Staffer's own travel to and from the Room they're cleaning --
## see the "Staffer Job travel" section near the bottom of this file. A
## Kitchen Staffer needs no travel of its own: Kitchen's Station post
## (sim/building_layout.gd's STATION_POST_ANCHOR_NAME) already sits at the
## Terrace pass, so _rebuild_staffers() only has to swap that Staffer's own
## CharacterSprite to its "working" state while a breakfast/dinner Job keeps
## them busy. Dragging a second Staffer onto an in-progress Job (either
## Station) Stacks them via the existing Sim.can_stack_*()/stack_staffer_on_*()
## calls, same gesture and validation ADR-0008 already specifies -- no rule
## duplicated here.

const BuildingLayout = preload("res://sim/building_layout.gd")
const CharacterSprite = preload("res://ui/character_sprite.gd")
const StafferActor = preload("res://ui/staffer_actor.gd")
const RoomBayActor = preload("res://ui/room_bay_actor.gd")
const RoomOccupantActor = preload("res://ui/room_occupant_actor.gd")
const DinerActor = preload("res://ui/diner_actor.gd")
const GuestActor = preload("res://ui/guest_actor.gd")
const NeedsBubble = preload("res://ui/needs_bubble.gd")
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
## before a press counts as a drag rather than a tap. For a Staffer or a
## lobby guest pick-up: below this it's a tap (opens the detail popup, or
## toggles the Needs bubble/selection), at or above it it's a drag (drop
## against a Station post to (re)assign, or a built Room bay to seat --
## ticket 11 -- or a no-op if released elsewhere). For an ordinary Room bay
## press (ticket 08, no Party selected) or the tap-then-tap seating press
## (ticket 11, a Party IS selected): the same threshold instead gates
## whether a release fires anything at all, since neither has a drag of its
## own -- a press that moves past it is simply abandoned rather than
## panning the camera.
const TAP_MOVEMENT_THRESHOLD := 6.0

## Generous drop-target box around a Station post's single anchor point
## (larger than the post's own STATION_PROP_SIZE render footprint) so a
## dropped Staffer doesn't have to land pixel-perfect on the prop.
const STATION_POST_HIT_SIZE := Vector2(60.0, 60.0)

## Where a tapped lobby guest's Needs bubble is anchored, relative to that
## guest's own origin (its footprint's bottom center) -- above both its own
## frame and its mood face, which sits at GuestActor.MOOD_FACE_OFFSET, so
## the bubble never overlaps either.
const NEEDS_BUBBLE_OFFSET := Vector2(0.0, -BuildingLayout.CHARACTER_FRAME_SIZE - BuildingLayout.MOOD_FACE_SIZE - 8.0)

## Ticket 11: while a guest (or Staffer) drag is in progress, holding the
## pointer within this many screen pixels of the viewport's top or bottom
## edge pans the camera toward that edge at AUTO_PAN_SPEED world units per
## second -- scaled by the current zoom, same screen-delta-to-world-delta
## division _pan_by() already uses, so the pan speed reads as constant on
## screen regardless of zoom level. Chosen over easing to fit-all on pickup
## (spec.md's "Further Notes": a known trade-off -- a long traverse is slow
## and the target floor isn't visible until it scrolls in).
const AUTO_PAN_EDGE_ZONE := 60.0
const AUTO_PAN_SPEED := 500.0

## Ticket 12: fixed real-time durations for a guest journey's three legs
## (walk to/from the shaft, ride, walk to/from the destination spot) --
## deliberately NOT derived from Sim's own tick counts (spec.md: "the
## elevator introduces no capacity limit, no queueing rule, and no new Sim
## state"; "the animation never gates the simulation"). The ride leg scales
## a little with floor distance so a top-floor trip reads as further than a
## Terrace-level hop, clamped so neither a same-floor edge case nor a very
## tall building produces a silly duration.
const JOURNEY_WALK_DURATION := 0.5
const JOURNEY_RIDE_DURATION_PER_FLOOR := 0.3
const JOURNEY_RIDE_DURATION_MIN := 0.3
const JOURNEY_RIDE_DURATION_MAX := 1.5
const JOURNEY_TURN_AWAY_DURATION := 0.8

## A small riding-only decoration parented to the travelling actor for the
## shaft-transit leg only (added/removed by _attach_elevator_car()/
## _detach_elevator_car()) -- "rides the car" (spec.md story 23) without a
## separate persistent car node to manage capacity/collision for, which the
## spec explicitly says the elevator never has.
const ELEVATOR_CAR_SIZE := Vector2(50.0, 70.0)
const ELEVATOR_CAR_COLOR := Color(0.55, 0.55, 0.6, 0.85)

## How far outside Reception's own front_desk anchor a turned-away Party or
## a checked-out guest walks out through -- there's no dedicated entrance
## anchor in the registry, so this is a fixed offset to the left of the
## building's own x=0 edge (BuildingLayout.BUILDING_WIDTH), mirroring the
## retired ui/room_occupancy_layer.gd's ENTRANCE_OFFSET_X.
const LOBBY_EXIT_LOCAL_X := -40.0

## Emitted whenever a Staffer is tapped (a press/release with no drag) so
## main_screen can open their existing Skill/Trait detail popup -- same
## contract as ui/station_panel.gd's retired staffer_tapped signal.
signal staffer_tapped(staffer_id: String)

## Emitted whenever a Room bay is tapped (ticket 08) -- a Build Slot
## (instance_id == -1) or an already-built Room (instance_id >= 0). An
## empty shell never emits this; it isn't a tap target. Same contract as
## ui/hotel_panel.gd's retired slot_selected signal, so main_screen's
## existing _on_hotel_slot_selected handler needs no changes to serve both.
signal room_slot_tapped(room_type_id: String, instance_id: int)

## Emitted whenever the Terrace's signage is tapped (ticket 09, ADR-0010's
## "tap the structure" gesture) so main_screen can open the existing
## Terrace menu, same contract as ui/terrace_panel.gd's retired
## terrace_tapped signal.
signal terrace_tapped

## Emitted whenever a seating gesture (a guest tap-then-bay-tap in
## _on_press()/_on_release(), or a guest dragged onto a bay via
## _attempt_seat_drop()) lands on a valid Match hint (ticket 11,
## ADR-0001/0009) -- hint is "green" or "amber", never "none" (an unseatable
## bay is never a tap/drop target in the first place). main_screen decides
## what "amber" means (the existing seat-confirm modal) and calls
## Sim.seat_party() itself; this world never seats a Party on its own.
signal party_seat_attempted(party_id: int, room_type_id: String, instance_id: int, hint: String)

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

## Screen pixels reserved at the top of the viewport for main_screen.gd's
## HudStrip (ticket 14) -- set by main_screen.gd before this node is added
## to the tree (so the very first ease_to_fit_all() already honours it),
## never mutated here. Zero (the default) reproduces this file's original,
## pre-ticket-14 fit-all framing exactly, which is what every camera/fit-all
## test-by-playtest has always exercised. Folded into both _fit_zoom() (so a
## tall building doesn't zoom in past the strip) and ease_to_fit_all()'s
## vertical centering (so the building is nudged down, out from under it)
## rather than into a separate "safe area" concept, since fit-all's own zoom
## and position are the only two places the strip's height needs to matter.
var hud_top_margin: float = 0.0

var _dragging := false

## Ticket 07: Station posts (station_id -> world Rect2 drop-target) and
## Staffer actors (staffer_id -> StafferActor), rebuilt whenever
## GameState.stations changes -- see _process()'s signature check below.
var _station_post_rects: Dictionary = {}
var _staffer_actors: Dictionary = {}
var _cached_stations_signature := ""

## Ticket 08: Room bay actors (room_type_id + bay index -> RoomBayActor),
## rebuilt whenever GameState.hotel_rooms changes (a build, a checkout
## leaving a Room dirty, a cleaning finishing, an upgrade purchased) -- see
## _process()'s signature check below, same pattern as _cached_stations_signature.
var _room_bay_actors: Dictionary = {}
var _cached_rooms_signature := ""

## Ticket 09: the Terrace's signage tap target, and every diner actor
## (Sim.walkin_queue entry id -> DinerActor), rebuilt whenever
## Sim.walkin_queue or its in-flight dinner Jobs change -- see _process()'s
## signature check below, same pattern as _cached_stations_signature.
var _terrace_tap_rect: Rect2 = Rect2()
var _diner_actors: Dictionary = {}
var _cached_dining_signature := ""

## Ticket 10: lobby guest actors ("<party_id>:<member_index>" -> GuestActor),
## rebuilt whenever Sim.pending_arrivals changes -- see _process()'s
## signature check below, same pattern as _cached_dining_signature. Since
## Patience decays every tick, this signature (unlike the structural ones
## above) changes every tick too, so a lobby guest's mood face is kept
## current by the same full rebuild that would otherwise only be needed for
## arrivals/departures -- mirroring _rebuild_diners()'s identical tradeoff.
var _lobby_guest_actors: Dictionary = {}
var _cached_lobby_signature := ""

## Ticket 12: every settled Room occupant's actor(s) -- room_key
## ("<room_type_id>:<instance_id>") -> Array[RoomOccupantActor] -- rebuilt
## alongside _room_bay_actors whenever the rooms signature changes (see
## _rooms_signature(), which folds in Clock.current_phase so a Night
## transition alone -- no hotel_rooms change -- still triggers the sleeping
## Zz swap). A room_key present in _active_room_journeys is skipped by that
## rebuild: the journey, not this dict, owns that Room's visible guest until
## it arrives (or leaves).
var _room_occupant_actors: Dictionary = {}

## Ticket 12: every in-flight guest journey (check-in or checkout), keyed by
## the SAME room_key _room_occupant_actors uses -- {phase: "waiting"|"moving",
## actor: CharacterSprite, tween: Tween, room_type_id: String, instance_id:
## int, species_id: String}. "waiting" is check-in-only (idling at the front
## desk until room["checking_in"] resolves, polled in _process() below);
## "moving" covers every walking/riding leg of either journey, driven
## entirely by the leg's own Tween and its finish callbacks. A checkout
## journey starts straight in "moving" -- there's no Sim-side delay to wait
## out on the way down, unlike check-in's flat checkin.delay_ticks.
var _active_room_journeys: Dictionary = {}

## Ticket 13: every in-flight Housekeeping Staffer Job travel, keyed by
## staffer_id (unlike _active_room_journeys above, which is keyed by
## room_key -- more than one Staffer can be travelling to the SAME Room at
## once, Stacked onto the same Job) -- {actor: CharacterSprite, tween:
## Tween, room_type_id: String, instance_id: int}. A tracked staffer_id is
## skipped entirely by _rebuild_staffers()'s ordinary post/nook render --
## this dict owns their visible actor until the Job resolves or they're
## reassigned elsewhere. A Kitchen Staffer never appears here: Kitchen's own
## Station post already sits at the Terrace pass, so there's nothing to
## travel to -- see _rebuild_staffers()'s own "working" state swap instead.
var _staffer_travel: Dictionary = {}

## Non-null while a Needs bubble is open (ticket 10) -- popped by tapping a
## lobby guest, closed by tapping that same guest again, tapping elsewhere,
## or the guest disappearing from a rebuild (seated, walked away, or the
## bubble's own Party simply no longer present). Parented to this node
## directly (like _drag_preview below) rather than to _building, so a
## structural rebuild (_rebuild_building(), which frees every _building
## child) can never leave this dangling.
var _needs_bubble: NeedsBubble = null
var _needs_bubble_key := ""

## Ticket 11: the party_id whose Needs bubble is currently open, if any --
## kept alongside _needs_bubble_key (which names the specific MEMBER the
## bubble is anchored to) since the Match hint glow and a seating attempt
## are both keyed on the whole Party, not one member. -1 means no Party is
## selected: every built bay's glow is "none" and a bay tap falls through to
## its normal (non-seating) tap behaviour. Set/cleared together with the
## bubble by _select_guest()/_close_needs_bubble().
var _selected_party_id := -1

## Non-empty while a lobby guest is picked up (press landed on a GuestActor's
## hit_rect()) -- the "<party_id>:<member_index>" key being dragged (a
## String, not a GuestActor reference, for the same reason
## _guest_key_at()'s caller resolves fresh below: _rebuild_lobby_guests()
## can free and recreate this actor mid-press since Patience decays every
## tick), its press-time world position (the tap-vs-drag threshold), and
## whether that guest's Party was ALREADY selected before this press (so
## release can tell "first tap, opened it" from "second tap, close it" --
## see _end_guest_drag()). Mutually exclusive with camera panning, a Staffer
## drag, and a Room bay press, same as every other gesture in this file.
var _drag_guest_key := ""
var _drag_guest_start_world := Vector2.ZERO
var _drag_guest_already_selected := false

## Non-empty while a Staffer is picked up (press landed on a StafferActor's
## hit_rect()) -- the id being dragged, its press-time world position (for
## the tap-vs-drag threshold), and a semi-transparent ghost sprite
## following the pointer. Mutually exclusive with _dragging (camera pan):
## a press either starts one or the other, never both.
var _drag_staffer_id := ""
var _drag_start_world := Vector2.ZERO
## Shared by a Staffer drag and a guest drag (never both at once) -- the
## semi-transparent ghost sprite following the pointer.
var _drag_preview: CharacterSprite = null

## The last press/motion/drag event's SCREEN-space position (not world --
## get_viewport_rect()'s own space, ticket 11's auto-pan edge check), kept
## for _auto_pan_if_near_edge() to poll every _process() tick rather than
## only on the input events that update it, since a stationary held pointer
## produces no further motion events of its own.
var _last_pointer_screen := Vector2.ZERO

## Non-null while a press has landed on a tappable Room bay (a Build Slot
## or a built Room, never an empty shell) with NO Party currently selected,
## awaiting release to decide tap vs. abandoned press (see
## TAP_MOVEMENT_THRESHOLD's comment). Mutually exclusive with both camera
## panning and a Staffer drag, same as those two already are with each
## other. See _press_seat_bay_actor below for the selected-Party case.
var _press_bay_actor: RoomBayActor = null
var _press_bay_start_world := Vector2.ZERO

## Ticket 11: non-null while a press has landed on a built Room bay that is
## a valid Match hint target (green or amber) for the currently selected
## Party -- the tap-then-tap half of ADR-0001/0009's seating gesture,
## coexisting with _press_bay_actor's ordinary build/inspect tap above (the
## two are mutually exclusive per press: see _on_press()). Awaiting release
## to decide tap vs. abandoned press, same TAP_MOVEMENT_THRESHOLD gate as
## every other press in this file.
var _press_seat_bay_actor: RoomBayActor = null
var _press_seat_bay_start_world := Vector2.ZERO

## Non-empty while a press has landed on the Terrace's signage tap target,
## awaiting release to decide tap vs. abandoned press -- same
## TAP_MOVEMENT_THRESHOLD-gated shape as _press_bay_actor above, mutually
## exclusive with a Staffer drag, a Room bay press, and camera panning.
var _press_terrace := false
var _press_terrace_start_world := Vector2.ZERO


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

	## Ticket 12: connected here (a scene node's _ready(), not an autoload's)
	## so that Sim's own EventBus connections -- made in its _ready(), which
	## always runs before any scene node's per Godot's autoload-before-
	## main-scene load order -- have already mutated GameState/pending_arrivals
	## by the time these run. _on_guest_turned_away() relies on exactly this
	## ordering to still find the departing Party's lobby actors before this
	## node's own next _process() rebuild removes them (same guarantee the
	## retired ui/room_occupancy_layer.gd documented for the same reason).
	EventBus.guest_seated.connect(_on_guest_seated)
	EventBus.guest_checked_out.connect(_on_guest_checked_out)
	EventBus.guest_turned_away.connect(_on_guest_turned_away)

	set_process(true)
	set_process_unhandled_input(true)


func _process(delta: float) -> void:
	_update_sky_tint()

	if _drag_staffer_id != "" or _drag_guest_key != "":
		_auto_pan_if_near_edge(delta)

	_poll_waiting_journeys()
	_sync_staffer_travel()

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

	## A build, a checkout, a cleaning finishing, or an upgrade purchase all
	## change hotel_rooms without changing the floor stack itself, so (like
	## Staffer reassignment above) only the Room bay actors need rebuilding.
	## Ticket 12: _rooms_signature() also folds in Clock.current_phase, since
	## a Night transition alone (no hotel_rooms mutation) still needs to swap
	## every settled occupant to its sleeping state.
	var rooms_signature := _rooms_signature()
	if rooms_signature != _cached_rooms_signature:
		_rebuild_room_bays(BuildingLayout.floors(GameState.rooms, GameState.stars))

	## A Walk-in Diner/Dining Party arriving, being claimed by a Kitchen
	## Staffer, being served, or walking away all change walkin_queue and/or
	## its in-flight dinner Jobs without changing the floor stack, so (same
	## pattern as the two signature checks above) only the diner actors need
	## rebuilding.
	var dining_signature := _dining_signature()
	if dining_signature != _cached_dining_signature:
		_cached_dining_signature = dining_signature
		_rebuild_diners(BuildingLayout.floors(GameState.rooms, GameState.stars))

	## A Party arriving, being (fully) seated, or walking away all change
	## pending_arrivals without changing the floor stack, same reasoning as
	## the dining signature above -- and, also like it, Patience decaying
	## every tick means this rebuilds every tick too, which is what keeps
	## every lobby guest's mood face current.
	var lobby_signature := _lobby_signature()
	if lobby_signature != _cached_lobby_signature:
		_cached_lobby_signature = lobby_signature
		_rebuild_lobby_guests(BuildingLayout.floors(GameState.rooms, GameState.stars))


## --- Building composition ---

func _rebuild_building() -> void:
	## Ticket 12: a floor unlocking mid-journey is a rare edge case (a
	## structural rebuild otherwise only happens on a floor unlock), but a
	## journey's actor is a child of _building about to be freed below, and
	## its Tween would otherwise keep trying to animate a freed object --
	## kill every in-flight journey's Tween first rather than let that
	## surface as an engine error. The Room simply renders without its guest
	## visible until Sim resolves it (checking_in flag, or a fresh
	## occupant), same graceful-degradation trade-off this file already
	## accepts elsewhere for a rebuild landing mid-gesture.
	for j in _active_room_journeys.values():
		if j.get("tween") != null and j["tween"].is_valid():
			j["tween"].kill()
	_active_room_journeys.clear()

	## Ticket 13: same defensive teardown as the guest journeys just above --
	## a Staffer Job travel actor is also a child of _building about to be
	## freed wholesale below.
	for j in _staffer_travel.values():
		if j.get("tween") != null and j["tween"].is_valid():
			j["tween"].kill()
	_staffer_travel.clear()

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
	_rebuild_room_bays(floors)
	_terrace_tap_rect = BuildingLayout.resolve_terrace_signage_rect(floors)
	_rebuild_diners(floors)
	_cached_dining_signature = _dining_signature()
	_rebuild_lobby_guests(floors)
	_cached_lobby_signature = _lobby_signature()

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
## resolve_character_sprite("staffer", id, ...) path for every Staffer,
## Manny included: he has no idle sheet, so he now renders his placeholder
## like anyone else's rest state would, rather than being special-cased
## into his walk-cycle demo. Ticket 13: a Staffer currently tracked in
## _staffer_travel (a Housekeeping Staffer mid-Job, travelling to or
## working at their actual Room) is skipped here entirely -- that dict
## owns their visible actor instead, so this pass would otherwise draw them
## twice. A Kitchen Staffer never travels (their Station post already sits
## at the Terrace pass), so they still render here, just swapped to the
## "working" state while a breakfast/dinner Job keeps them busy. Called on
## structural rebuilds and whenever GameState.stations changes (see
## _process()), never mid-drag: the Staffer actually being dragged is only
## ever moved by our own Sim.assign_staffer()/Sim.stack_staffer_on_*() call
## at drop, which happens after the drag has already ended.
func _rebuild_staffers(floors: Array) -> void:
	for actor in _staffer_actors.values():
		actor.queue_free()
	_staffer_actors.clear()

	var placements := BuildingLayout.staffer_placements(GameState.stations, GameState.staffers.keys())
	for staffer_id in placements.keys():
		if _staffer_travel.has(staffer_id):
			continue
		var point: Vector2 = BuildingLayout.resolve_staffer_point(floors, placements[staffer_id])
		var actor := StafferActor.new()
		_building.add_child(actor)
		var state := "working" if _kitchen_job_active(staffer_id) else "idle"
		actor.configure(staffer_id, state)
		actor.position = point
		_staffer_actors[staffer_id] = actor


## True iff staffer_id is currently mid-breakfast XOR mid-dinner (ADR-0005:
## _kitchen_busy() means never both at once) -- _rebuild_staffers()'s own
## "working" state swap for a Kitchen Staffer, who (unlike a Housekeeping
## Staffer) never leaves their Station post to earn it.
func _kitchen_job_active(staffer_id: String) -> bool:
	return not Sim.breakfast_job(staffer_id).is_empty() or not Sim.dinner_job(staffer_id).is_empty()


## --- Room bays (ticket 08) ---
##
## Every Room floor draws exactly two bays (bay_left, bay_right -- the
## anchor registry) whose content -- a built Room, a Build Slot, or an
## empty shell -- comes from BuildingLayout.room_bay_states(), and whose
## visual state (occupancy/dirt/upgrades) comes from
## room_bay_visual_state() reading that instance's own GameState.hotel_rooms
## entry. Rebuilt on every structural rebuild and whenever
## GameState.hotel_rooms changes (see _process()), never mid-tap.
func _rebuild_room_bays(floors: Array) -> void:
	for actor in _room_bay_actors.values():
		actor.queue_free()
	_room_bay_actors.clear()

	for actors in _room_occupant_actors.values():
		for actor in actors:
			actor.queue_free()
	_room_occupant_actors.clear()

	for i in range(floors.size()):
		var f: Dictionary = floors[i]
		if f["kind"] != "room":
			continue
		var room_type_id: String = String(f["room_type_id"])
		var level: int = int(f["level"])
		var bay_states := BuildingLayout.room_bay_states(GameState.floor_instance_count(room_type_id), GameState.can_build_more(room_type_id))

		for bay_index in range(bay_states.size()):
			var anchor_name := "bay_left" if bay_index == 0 else "bay_right"
			var rect: Rect2 = BuildingLayout.resolve_anchor(floors, i, anchor_name)
			var bay_state: Dictionary = bay_states[bay_index]

			var visual_state: Dictionary = {}
			if bay_state["state"] == "built":
				var room := GameState.room_instance(room_type_id, int(bay_state["instance_id"]))
				visual_state = BuildingLayout.room_bay_visual_state(room)
				if visual_state["dirty"]:
					visual_state["mess_progress"] = _room_mess_progress(room_type_id, int(bay_state["instance_id"]))
				_rebuild_room_occupants(floors, i, room_type_id, int(bay_state["instance_id"]), room)

			var actor := RoomBayActor.new()
			_building.add_child(actor)
			actor.configure(room_type_id, bay_state, rect.size, BuildingLayout.room_number(level, bay_index), visual_state)
			actor.position = rect.position
			_room_bay_actors["%s:%d" % [room_type_id, bay_index]] = actor

	_cached_rooms_signature = _rooms_signature()
	_refresh_bay_match_hints()


## Ticket 12: renders a built Room's settled occupant(s), one RoomOccupantActor
## per visible member at BuildingLayout.resolve_room_occupant_point()'s fixed
## in-bay spot -- skipped entirely (no actors spawned) while the Room's
## occupant hasn't visually arrived yet, so the static render and the
## in-flight journey never show the same guest twice:
##  - room["checking_in"] is still true (Sim admitted the Party already, but
##    its flat check-in delay hasn't resolved) -- belt-and-suspenders with
##    the check below, in case a structural rebuild ever drops the journey
##    entry itself (see _rebuild_building()'s own comment on that edge case).
##  - room_key names an entry in _active_room_journeys -- the journey (either
##    direction) owns this Room's guest right now.
## Species/party_size come from Sim.guests (the authoritative stay record),
## not the room's own occupant_species_id/occupant_name mirror fields, since
## only the guest record carries party_size.
func _rebuild_room_occupants(floors: Array, floor_index: int, room_type_id: String, instance_id: int, room: Dictionary) -> void:
	var room_key := _room_key(room_type_id, instance_id)
	if room.get("checking_in", false) or _active_room_journeys.has(room_key):
		return

	var occupant_id = room.get("occupant")
	if occupant_id == null:
		return
	var guest: Dictionary = Sim.guests.get(int(occupant_id), {})
	if guest.is_empty():
		return

	var species_id: String = String(guest.get("species_id", room.get("occupant_species_id", "")))
	var party_size: int = int(guest.get("party_size", 1))
	var sleeping := Clock.current_phase == Clock.Phase.NIGHT

	var actors: Array = []
	var placements := BuildingLayout.room_occupant_placements(party_size)
	for member_index in range(placements.size()):
		var actor := RoomOccupantActor.new()
		_building.add_child(actor)
		actor.configure(species_id, sleeping)
		actor.position = BuildingLayout.resolve_room_occupant_point(floors, floor_index, instance_id, member_index)
		actors.append(actor)
	_room_occupant_actors[room_key] = actors


## Folds Clock.current_phase into the rooms rebuild signature (_process()'s
## own gate) so a Night transition alone -- no hotel_rooms mutation -- still
## re-triggers _rebuild_room_bays() and therefore _rebuild_room_occupants()'s
## sleeping-state swap.
func _rooms_signature() -> String:
	return str(GameState.hotel_rooms) + "|" + str(int(Clock.current_phase)) + "|" + _cleaning_progress_signature()


## Ticket 13: folds every in-flight Housekeeping Job's own ticks_remaining
## into the rooms signature above, so a Job progressing (no hotel_rooms
## mutation of its own -- needs_cleaning only flips at the very end) still
## re-triggers _rebuild_room_bays() every tick, the same "full rebuild every
## tick while something is continuously changing" trade-off
## _lobby_signature()/_dining_signature() already make for Patience decay.
## Empty (and therefore a no-op on the signature) whenever no Room is
## dirty, unlike those two, which always change every tick regardless.
func _cleaning_progress_signature() -> String:
	var parts: Array = []
	for room in GameState.hotel_rooms:
		if not bool(room.get("needs_cleaning", false)):
			continue
		for staffer_id in Sim.cleaning_staffers(String(room["room_type_id"]), int(room["instance_id"])):
			parts.append(str(Sim.cleaning_job(staffer_id).get("ticks_remaining", -1)))
	return "|".join(parts)


## Shared by every Room-addressing dict in this file (_room_occupant_actors,
## _active_room_journeys) -- room_type_id + instance_id, matching
## sim/match_hint.gd's own room_key() shape without importing that class
## just for this.
func _room_key(room_type_id: String, instance_id: int) -> String:
	return "%s:%d" % [room_type_id, instance_id]


## Ticket 11: re-applies the currently selected Party's Match hint glow to
## every built Room bay actor (RoomBayActor.set_match_hint(), which updates
## in place rather than tearing anything down) -- called both after a
## structural bay rebuild (a build/checkout/clean/upgrade could change which
## Rooms are even valid targets) and whenever the selection itself changes
## (a guest tap or pick-up, or the bubble closing). _selected_party_id == -1
## resolves every bay to "none" via BuildingLayout.room_bay_match_hint()'s
## own early-out, clearing every glow with no Sim.match_hint() calls at all.
func _refresh_bay_match_hints() -> void:
	for actor in _room_bay_actors.values():
		if actor.state == "built":
			actor.set_match_hint(BuildingLayout.room_bay_match_hint(_selected_party_id, actor.room_type_id, actor.instance_id))


## --- Terrace: signage tap target, and diner placement (ticket 09) ---
##
## The Terrace's signage is the one tap target on its band (ADR-0010's
## "tap the structure" gesture) -- opens the existing Terrace menu
## unchanged (main_screen._on_terrace_tapped). Every Sim.walkin_queue entry
## (Walk-in Diner or Dining Party alike, CONTEXT.md) stands either at the
## pass (being served -- Sim.dinner_jobs() names its entry_id) or the
## entrance queue (still waiting), per
## BuildingLayout.terrace_diner_placements() -- so a busy dinner service
## reads as diners visibly seated along the pass, and the number of diners
## on screen always tracks Sim.walkin_queue's own size, with no list to
## read.

func _rebuild_diners(floors: Array) -> void:
	for actor in _diner_actors.values():
		actor.queue_free()
	_diner_actors.clear()

	var patience_cfg: Dictionary = GameState.balance.get("dining", {}).get("walkin_patience", {})
	var placements := BuildingLayout.terrace_diner_placements(Sim.walkin_queue, Sim.dinner_jobs())
	for entry in Sim.walkin_queue:
		var entry_id: int = int(entry["id"])
		var point: Vector2 = BuildingLayout.resolve_terrace_diner_point(floors, placements[entry_id])
		var actor := DinerActor.new()
		_building.add_child(actor)
		actor.configure(String(entry["species_id"]))
		actor.position = point
		actor.update_mood(float(entry["patience"]), patience_cfg)
		_diner_actors[entry_id] = actor


func _dining_signature() -> String:
	return str(Sim.walkin_queue) + "|" + str(Sim.dinner_jobs())


## --- Lobby guests: mood faces, Needs bubbles, and selection (tickets 10/11) ---
##
## An arriving Party stands in the lobby as one GuestActor per member
## (sim/building_layout.gd's lobby_guest_placements()), each carrying an
## always-visible mood face that sours as its own Party's Patience decays
## (BuildingLayout.resolve_mood_face_for_patience(), GameState.balance's
## "patience" block -- the same config Sim._decay_patience() decays
## pending_arrivals against).
##
## Picking a guest up -- by a tap or the start of a drag, ADR-0009's "both
## gestures put the Party into the same selected state" -- pops a Needs
## bubble of Tag icons for its Party and glows every built bay's Match hint
## (_select_guest(), _refresh_bay_match_hints()). A tap that lands on an
## already-selected guest closes it again (_end_guest_drag()); tapping a
## different guest, or dragging one onto a bay, are handled by the
## tap/drag gesture code below.

func _lobby_signature() -> String:
	return str(Sim.pending_arrivals)


func _rebuild_lobby_guests(floors: Array) -> void:
	for actor in _lobby_guest_actors.values():
		actor.queue_free()
	_lobby_guest_actors.clear()

	var patience_cfg: Dictionary = GameState.balance["patience"]
	for placement in BuildingLayout.lobby_guest_placements(Sim.pending_arrivals):
		var party_id: int = int(placement["party_id"])
		var member_index: int = int(placement["member_index"])
		var party := Sim.pending_party(party_id)
		var point: Vector2 = BuildingLayout.resolve_lobby_guest_point(floors, int(placement["queue_index"]))

		var actor := GuestActor.new()
		_building.add_child(actor)
		actor.configure(party_id, member_index, String(party["species_id"]))
		actor.position = point
		actor.update_mood(float(party["patience"]), patience_cfg)
		_lobby_guest_actors[_guest_key(party_id, member_index)] = actor

	## A rebuild can drop the guest a currently-open Needs bubble belongs to
	## (its Party got seated or walked away) or shift it to a new queue
	## position (an earlier Party leaving pulls everyone behind it forward)
	## -- close the bubble in the first case, follow the guest in the
	## second, rather than leaving it anchored to a stale position or a
	## freed actor.
	if _needs_bubble != null:
		if _lobby_guest_actors.has(_needs_bubble_key):
			_needs_bubble.position = _lobby_guest_actors[_needs_bubble_key].position + NEEDS_BUBBLE_OFFSET
		else:
			_close_needs_bubble()


func _guest_key(party_id: int, member_index: int) -> String:
	return "%d:%d" % [party_id, member_index]


func _guest_key_at(world_pos: Vector2) -> String:
	for key in _lobby_guest_actors.keys():
		var actor: GuestActor = _lobby_guest_actors[key]
		if actor.hit_rect().has_point(world_pos):
			return key
	return ""


## Opens (or refreshes) a Needs bubble for the guest at `key` and selects
## its whole Party for seating -- idempotent, so re-selecting the
## already-open guest (e.g. _begin_guest_drag() unconditionally calling this
## on every press, including a second tap meant to close it) just
## reconfigures the same bubble in place rather than flickering it shut and
## open again. A no-op if `key` no longer names a live guest (its Party
## resolved between press and release).
func _select_guest(key: String) -> void:
	if not _lobby_guest_actors.has(key):
		return
	var actor: GuestActor = _lobby_guest_actors[key]
	var party := Sim.pending_party(actor.party_id)
	if party.is_empty():
		return

	if _needs_bubble == null:
		_needs_bubble = NeedsBubble.new()
		add_child(_needs_bubble)
	_needs_bubble.configure((party["needs"] as Array).duplicate())
	_needs_bubble.position = actor.position + NEEDS_BUBBLE_OFFSET
	_needs_bubble_key = key
	_selected_party_id = actor.party_id
	_refresh_bay_match_hints()


func _close_needs_bubble() -> void:
	if _needs_bubble != null:
		_needs_bubble.queue_free()
		_needs_bubble = null
	_needs_bubble_key = ""
	_selected_party_id = -1
	_refresh_bay_match_hints()


## --- Elevator journeys: check-in, checkout, turn-away (ticket 12) ---
##
## Every journey is a single CharacterSprite tweened through world space in
## real time, decoupled from Sim's own tick-driven timing (spec.md: "the
## animation never gates the simulation") -- Sim's admission/checkout/
## walk-away already happened by the time any of these handlers run (same
## "not a source of truth" caveat EventBus's own class doc carries for these
## signals), so nothing here can affect or delay it.

func _on_guest_seated(_guest_name: String, species_id: String, room_type_id: String, instance_id: int, _mismatch: bool) -> void:
	var room_key := _room_key(room_type_id, instance_id)
	_cancel_journey(room_key) # defensive: a same-Room checkout journey shouldn't collide with a fresh check-in (can't happen today -- a stay is never <1 night -- but see _rebuild_building()'s own defensive cancellation)

	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)
	var actor := CharacterSprite.new()
	_building.add_child(actor)
	actor.configure(BuildingLayout.resolve_character_sprite("guest", species_id, "idle"))
	actor.position = BuildingLayout.resolve_anchor(floors, 0, "front_desk")

	_active_room_journeys[room_key] = _new_journey("waiting", actor, room_type_id, instance_id, species_id)


## Shared {phase, actor, tween, room_type_id, instance_id, species_id} record
## shape for _active_room_journeys, built identically by both
## _on_guest_seated() (phase "waiting") and _on_guest_checked_out() (phase
## "moving", no wait of its own -- see that function's header comment).
func _new_journey(phase: String, actor: CharacterSprite, room_type_id: String, instance_id: int, species_id: String) -> Dictionary:
	return {
		"phase": phase,
		"actor": actor,
		"tween": null,
		"room_type_id": room_type_id,
		"instance_id": instance_id,
		"species_id": species_id,
	}


## Polls every check-in journey still idling at the front desk against its
## own Room's room["checking_in"] flag -- Sim's flat checkin.delay_ticks
## countdown (_start_checkin()/_tick_checkins()) is the one and only source
## of that wait's duration; this loop only notices when it's over; it never
## re-times it. A Room that's vanished (defensive only) resolves the same as
## checking_in going false, so a journey can never be stranded waiting on a
## Room that no longer exists.
func _poll_waiting_journeys() -> void:
	for room_key in _active_room_journeys.keys().duplicate():
		var j: Dictionary = _active_room_journeys[room_key]
		if j["phase"] != "waiting":
			continue
		var room := GameState.room_instance(j["room_type_id"], j["instance_id"])
		if room.is_empty() or not room.get("checking_in", false):
			_begin_checkin_ride(room_key, j)


## The walk-to-shaft / ride / walk-to-room leg of a check-in journey, played
## once Sim's own check-in delay has resolved (see _poll_waiting_journeys()).
func _begin_checkin_ride(room_key: String, j: Dictionary) -> void:
	j["phase"] = "moving"
	var actor: CharacterSprite = j["actor"]
	actor.configure(BuildingLayout.resolve_character_sprite("guest", j["species_id"], "walk"))

	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)
	var room_floor_index := BuildingLayout.floor_index_for_room_type(floors, j["room_type_id"])
	if room_floor_index == -1: # defensive only -- every caller sources room_type_id from a live GameState.hotel_rooms entry
		_cancel_journey(room_key)
		return

	var reception_door: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "elevator_door")
	var room_door: Vector2 = BuildingLayout.resolve_anchor(floors, room_floor_index, "elevator_door")
	var destination: Vector2 = BuildingLayout.resolve_room_occupant_point(floors, room_floor_index, j["instance_id"], 0)

	_play_ride_legs(j, reception_door, room_door, destination, room_floor_index, _finish_checkin_journey.bind(room_key))


## The walk/ride/walk leg sequence shared by both directions of the elevator
## journey (check-in's front-desk-to-Room and checkout's Room-to-lobby-exit)
## -- three chained tween_property() calls, sequential by default (no
## set_parallel(true), unlike _pan_by()'s camera tween elsewhere in this
## file), with the riding-only car decoration attached/detached around the
## middle leg. `j["tween"]` is stored so _cancel_journey()/_rebuild_building()
## can kill it if the journey needs to be torn down mid-flight.
func _play_ride_legs(j: Dictionary, leg_a: Vector2, leg_b: Vector2, leg_c: Vector2, floors_traveled: int, finish_cb: Callable) -> void:
	var actor: CharacterSprite = j["actor"]
	var ride_duration := _ride_duration(floors_traveled)

	var tween := create_tween()
	j["tween"] = tween
	tween.tween_property(actor, "position", leg_a, JOURNEY_WALK_DURATION)
	tween.tween_callback(_attach_elevator_car.bind(actor))
	tween.tween_property(actor, "position", leg_b, ride_duration)
	tween.tween_callback(_detach_elevator_car.bind(actor))
	tween.tween_property(actor, "position", leg_c, JOURNEY_WALK_DURATION)
	tween.tween_callback(finish_cb)


## Arrival: frees the journey's own travelling actor and hands the Room back
## to the ordinary occupant render pass -- forced immediately (rather than
## waiting for the next signature-driven rebuild) so there's no one-frame gap
## with no guest visible at all.
func _finish_checkin_journey(room_key: String) -> void:
	var j: Dictionary = _active_room_journeys.get(room_key, {})
	if j.is_empty():
		return
	if j.get("actor") != null:
		j["actor"].queue_free()
	_active_room_journeys.erase(room_key)
	_rebuild_room_bays(BuildingLayout.floors(GameState.rooms, GameState.stars))


## Checkout's journey is the exact reverse of check-in's ride/walk legs, with
## no "waiting" phase of its own -- unlike admission, Sim.checkout has no
## flat delay to poll for, so the walk-out starts the instant this fires.
## EventBus.guest_checked_out is emitted BEFORE Sim clears the Room's own
## occupant fields (sim_controller.gd's _checkout_guest()), so this handler
## runs while GameState.room_instance() still reports the departing guest --
## claiming room_key into _active_room_journeys here, before this node's own
## next _process() rebuild, is what keeps the ordinary occupant render pass
## from drawing that same guest a second time already leaving.
func _on_guest_checked_out(_guest_name: String, species_id: String, room_type_id: String, instance_id: int) -> void:
	var room_key := _room_key(room_type_id, instance_id)
	_cancel_journey(room_key) # defensive: an in-flight check-in for this Room shouldn't collide with its checkout (can't happen today -- see _on_guest_seated()'s matching comment)

	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)
	var room_floor_index := BuildingLayout.floor_index_for_room_type(floors, room_type_id)
	if room_floor_index == -1: # defensive only, mirrors _begin_checkin_ride()'s own guard
		return

	var actor := CharacterSprite.new()
	_building.add_child(actor)
	actor.configure(BuildingLayout.resolve_character_sprite("guest", species_id, "walk"))
	actor.position = BuildingLayout.resolve_room_occupant_point(floors, room_floor_index, instance_id, 0)

	var j := _new_journey("moving", actor, room_type_id, instance_id, species_id)
	_active_room_journeys[room_key] = j

	var room_door: Vector2 = BuildingLayout.resolve_anchor(floors, room_floor_index, "elevator_door")
	var reception_door: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "elevator_door")
	var exit_point := _lobby_exit_point(floors)

	_play_ride_legs(j, room_door, reception_door, exit_point, room_floor_index, _finish_checkout_journey.bind(room_key))


func _finish_checkout_journey(room_key: String) -> void:
	var j: Dictionary = _active_room_journeys.get(room_key, {})
	if j.is_empty():
		return
	if j.get("actor") != null:
		j["actor"].queue_free()
	_active_room_journeys.erase(room_key)


## A turned-away Party's own lobby actors (every "<party_id>:<member_index>"
## key in _lobby_guest_actors, per ADR-... spec.md story 14's "a Party of
## three is three characters") walk back out through the lobby together, no
## elevator involved -- ticket 09/10's Terrace/lobby have their own separate
## queues, but a Room-booking Party never touches the elevator until it's
## actually seated. Relies on the same connection-order guarantee
## _ready()'s own comment documents: Sim's pending_arrivals.erase() already
## happened by the time this runs, but this node's own next _process()
## rebuild (which would free these same actors) hasn't yet -- so their
## current positions are still the Party's real, live queue spots, not a
## fixed stand-in.
func _on_guest_turned_away(_guest_name: String, species_id: String, _reason: String, party_id: int) -> void:
	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)
	var exit_point := _lobby_exit_point(floors)
	var prefix := "%d:" % party_id
	for key in _lobby_guest_actors.keys():
		if not key.begins_with(prefix):
			continue
		_spawn_turn_away_ghost(_lobby_guest_actors[key].position, species_id, exit_point)


func _spawn_turn_away_ghost(start: Vector2, species_id: String, exit_point: Vector2) -> void:
	var actor := CharacterSprite.new()
	_building.add_child(actor)
	actor.configure(BuildingLayout.resolve_character_sprite("guest", species_id, "walk"))
	actor.position = start

	var tween := create_tween()
	tween.tween_property(actor, "position", exit_point, JOURNEY_TURN_AWAY_DURATION)
	tween.tween_callback(actor.queue_free)


## Kills room_key's in-flight journey (if any) and frees its travelling
## actor immediately, with no completion side effects -- used defensively
## where a fresh journey is about to claim a Room a stale one might still
## (impossibly, today) hold onto. Not used for the ordinary "arrived" case;
## that's _finish_checkin_journey()/_finish_checkout_journey().
func _cancel_journey(room_key: String) -> void:
	var j: Dictionary = _active_room_journeys.get(room_key, {})
	if j.is_empty():
		return
	if j.get("tween") != null and j["tween"].is_valid():
		j["tween"].kill()
	if j.get("actor") != null:
		j["actor"].queue_free()
	_active_room_journeys.erase(room_key)


## The ride leg's duration, scaled a little by floor distance so a top-floor
## trip reads as further than a Terrace-level hop -- see
## JOURNEY_RIDE_DURATION_PER_FLOOR's comment.
func _ride_duration(room_floor_index: int) -> float:
	return clampf(float(room_floor_index) * JOURNEY_RIDE_DURATION_PER_FLOOR, JOURNEY_RIDE_DURATION_MIN, JOURNEY_RIDE_DURATION_MAX)


## Reception's front_desk anchor, offset to the left of the building's own
## x=0 edge -- see LOBBY_EXIT_LOCAL_X's comment.
func _lobby_exit_point(floors: Array) -> Vector2:
	var front_desk: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "front_desk")
	return Vector2(LOBBY_EXIT_LOCAL_X, front_desk.y)


## Attaches/removes the riding-only car decoration (ELEVATOR_CAR_SIZE/
## ELEVATOR_CAR_COLOR) as a child of the travelling actor, so it moves with
## the actor for free during the shaft-transit leg only -- see the
## constant's own header comment for why this is simpler than a shared,
## persistent car node.
func _attach_elevator_car(actor: CharacterSprite) -> void:
	var car := ColorRect.new()
	car.name = "ElevatorCar"
	car.color = ELEVATOR_CAR_COLOR
	car.size = ELEVATOR_CAR_SIZE
	car.position = Vector2(-ELEVATOR_CAR_SIZE.x / 2.0, -ELEVATOR_CAR_SIZE.y)
	car.mouse_filter = Control.MOUSE_FILTER_IGNORE
	car.z_index = -1
	actor.add_child(car)


func _detach_elevator_car(actor: CharacterSprite) -> void:
	var car := actor.get_node_or_null("ElevatorCar")
	if car != null:
		car.queue_free()


## --- Staffer Job travel: Housekeeping travel and Stacking (ticket 13) ---
##
## A Housekeeping Staffer's travel mirrors the guest elevator journey above
## (_play_ride_legs() is shared verbatim) but is polled every frame against
## Sim.cleaning_job() rather than event-driven, since Housekeeping/Kitchen
## Jobs (unlike check-in/checkout) fire no per-Job start/end signal of their
## own -- sim_controller.gd's own _tick_housekeeping()/_drop_staffer_jobs()
## silently create and erase _cleaning_jobs entries each tick. A tracked
## staffer_id whose Job entry has disappeared this tick is "resolved" (the
## ticket's "works there until it completes, then returns" -- plays a
## return trip) if their target Room actually cleared (needs_cleaning
## flipped false), or "interrupted" (the ticket's "reassigning ... interrupts
## their travel immediately" -- freed on the spot, no return trip) otherwise,
## since a reassignment (Sim.assign_staffer()) or a Stack-elsewhere
## (Sim.stack_staffer_on_room() onto a DIFFERENT Room) both drop a Job entry
## without ever clearing its old target's needs_cleaning flag. Stacking a
## second Staffer onto an already-claimed Job (ADR-0008) needs no special
## case: it's just another staffer_id independently discovered by the same
## per-frame sweep, travelling to the very same room_type_id/instance_id.
##
## Kitchen has no equivalent travel: see _kitchen_job_active()'s own doc
## comment on _rebuild_staffers() above.

func _sync_staffer_travel() -> void:
	var active: Dictionary = {}
	for staffer_id in GameState.station_staffers("housekeeping"):
		var job := Sim.cleaning_job(staffer_id)
		if job.is_empty():
			continue
		active[staffer_id] = true
		var room_type_id: String = String(job["room_type_id"])
		var instance_id: int = int(job["instance_id"])
		var entry: Dictionary = _staffer_travel.get(staffer_id, {})
		if entry.is_empty() or entry["room_type_id"] != room_type_id or entry["instance_id"] != instance_id:
			_start_staffer_travel(staffer_id, room_type_id, instance_id)

	for staffer_id in _staffer_travel.keys().duplicate():
		if active.has(staffer_id):
			continue
		var entry: Dictionary = _staffer_travel[staffer_id]
		var room := GameState.room_instance(entry["room_type_id"], entry["instance_id"])
		var resolved: bool = room.is_empty() or not bool(room.get("needs_cleaning", false))
		_end_staffer_travel(staffer_id, resolved)


## Starts staffer_id's outbound leg from the Housekeeping post to the actual
## Room they just claimed, via the same walk/ride/walk shape as a guest
## check-in -- always departing from the post's own fixed anchor rather than
## wherever the Staffer happened to be standing, mirroring the retired
## ui/staff_job_travel_layer.gd's own _home_anchor() convention. Frees any
## stale entry first (_cancel_staffer_travel()) so a mid-Job retarget --
## Sim.stack_staffer_on_room() dragging this same Staffer onto a DIFFERENT
## Room while their old Job is still in flight -- cuts immediately to the
## new target with no return trip, rather than being mistaken for the
## ordinary "already there" case.
func _start_staffer_travel(staffer_id: String, room_type_id: String, instance_id: int) -> void:
	_cancel_staffer_travel(staffer_id)

	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)
	var room_floor_index := BuildingLayout.floor_index_for_room_type(floors, room_type_id)
	if room_floor_index == -1: # defensive only -- every caller sources room_type_id from a live Sim.cleaning_job()
		return

	var actor := CharacterSprite.new()
	_building.add_child(actor)
	actor.configure(BuildingLayout.resolve_character_sprite("staffer", staffer_id, "walk"))
	actor.position = BuildingLayout.resolve_station_post_anchor(floors, "housekeeping")

	## Snapshotted once, at claim time, for _room_mess_progress()'s fade --
	## see that function's own doc comment for why Stacking's later recompute
	## can never push ticks_remaining above this baseline.
	var total_ticks := int(Sim.cleaning_job(staffer_id).get("ticks_remaining", 0))
	var j := {"actor": actor, "tween": null, "room_type_id": room_type_id, "instance_id": instance_id, "total_ticks": total_ticks}
	_staffer_travel[staffer_id] = j

	var post_door: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "elevator_door")
	var room_door: Vector2 = BuildingLayout.resolve_anchor(floors, room_floor_index, "elevator_door")
	var destination: Vector2 = BuildingLayout.resolve_room_housekeeper_point(floors, room_floor_index, instance_id)

	_play_ride_legs(j, post_door, room_door, destination, room_floor_index, _arrive_staffer_travel.bind(staffer_id))


## Arrival: swaps the travelling actor to its "working" state and leaves it
## parked at the Room -- _play_ride_legs()'s own last leg already placed it
## there, so there's nothing left to move.
func _arrive_staffer_travel(staffer_id: String) -> void:
	var j: Dictionary = _staffer_travel.get(staffer_id, {})
	if j.is_empty():
		return
	var actor: CharacterSprite = j["actor"]
	actor.configure(BuildingLayout.resolve_character_sprite("staffer", staffer_id, "working"))


## Ends staffer_id's tracked travel. A resolved Job (the ticket's "then
## returns") plays a return trip from wherever the actor currently stands
## back to the Housekeeping post before freeing it and forcing
## _rebuild_staffers() -- reassignment plays no part in a natural
## completion, so GameState.stations (and therefore the ordinary
## stations_signature-driven rebuild in _process()) never changes on its
## own here, unlike the interrupted branch below. An interrupted one (the
## ticket's "interrupts their travel immediately") frees it on the spot with
## no return trip: GameState.stations DID just change (a reassignment or a
## Stack-elsewhere caused this), so _process()'s own stations_signature
## check -- which always runs later in the same frame, since
## _sync_staffer_travel() is called before it -- renders the Staffer at
## their new post or the nook the moment this function returns.
func _end_staffer_travel(staffer_id: String, resolved: bool) -> void:
	var j: Dictionary = _staffer_travel.get(staffer_id, {})
	if j.is_empty():
		return
	_staffer_travel.erase(staffer_id)

	var outbound_tween: Tween = j.get("tween")
	if outbound_tween != null and outbound_tween.is_valid():
		outbound_tween.kill() # in case the Job resolved before the outbound leg ever finished

	var actor: CharacterSprite = j["actor"]
	if not resolved:
		actor.queue_free()
		return

	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)
	var room_floor_index := BuildingLayout.floor_index_for_room_type(floors, j["room_type_id"])
	if room_floor_index == -1: # defensive only, mirrors _start_staffer_travel()'s own guard
		actor.queue_free()
		_rebuild_staffers(floors)
		return

	actor.configure(BuildingLayout.resolve_character_sprite("staffer", staffer_id, "walk"))
	var room_door: Vector2 = BuildingLayout.resolve_anchor(floors, room_floor_index, "elevator_door")
	var post_door: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "elevator_door")
	var post: Vector2 = BuildingLayout.resolve_station_post_anchor(floors, "housekeeping")

	var ret := {"actor": actor, "tween": null}
	_play_ride_legs(ret, room_door, post_door, post, room_floor_index, _finish_staffer_return.bind(actor))


## The return trip's own finish callback: frees the now-arrived actor and
## forces _rebuild_staffers() so the ordinary post render picks the Staffer
## back up immediately, rather than waiting for a stations_signature change
## that (per _end_staffer_travel()'s own doc) never comes on a natural
## completion.
func _finish_staffer_return(actor: CharacterSprite) -> void:
	actor.queue_free()
	_rebuild_staffers(BuildingLayout.floors(GameState.rooms, GameState.stars))


## Kills staffer_id's in-flight travel (if any) and frees its actor
## immediately, with no completion side effects -- used defensively where a
## fresh travel is about to claim a Staffer a stale one might still hold
## (a mid-Job retarget via Stacking, per _start_staffer_travel()'s own doc).
func _cancel_staffer_travel(staffer_id: String) -> void:
	var stale: Dictionary = _staffer_travel.get(staffer_id, {})
	if stale.is_empty():
		return
	var tween: Tween = stale.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	if stale.get("actor") != null:
		stale["actor"].queue_free()
	_staffer_travel.erase(staffer_id)


## How far a Room's Housekeeping Job has visibly progressed (spec.md story
## 31, the ticket's "mess visibly disappears as the Job progresses") -- 1.0
## (full mess) whenever no tracked Staffer is targeting the Room, otherwise
## interpolated against the SAME Sim.cleaning_job() ticks_remaining
## countdown _sync_staffer_travel() already polls, purely as a presentation
## fade: the HK_TICKS_BY_SKILL lookup itself is never re-derived here, only
## observed. The baseline is _staffer_travel[staffer_id]["total_ticks"],
## snapshotted once at claim time -- Stacking's own recompute
## (Sim.stack_staffer_on_room(), ADR-0008) sums Skill, which the balance
## table maps to a ticks_remaining that's always <= a lower/solo Skill's own
## total, so this can never run backwards past 1.0 or negative past 0.0 (the
## clampf() below is belt-and-suspenders only). More than one Staffer can be
## Stacked on the same Job; either one's own tracked entry gives the same
## live ticks_remaining (stack_staffer_on_room() sets both identically), so
## the first one found is enough.
func _room_mess_progress(room_type_id: String, instance_id: int) -> float:
	for staffer_id in Sim.cleaning_staffers(room_type_id, instance_id):
		var entry: Dictionary = _staffer_travel.get(staffer_id, {})
		var total: int = int(entry.get("total_ticks", 0))
		if total <= 0:
			continue
		var remaining: int = int(Sim.cleaning_job(staffer_id).get("ticks_remaining", total))
		return clampf(float(remaining) / float(total), 0.0, 1.0)
	return 1.0


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


## An empty shell is never a tap target (BuildingLayout.room_bay_states()
## never gives it a meaningful instance_id to act on), so it's skipped here
## rather than being handed to the caller to filter out.
func _tappable_room_bay_at(world_pos: Vector2) -> RoomBayActor:
	for actor in _room_bay_actors.values():
		if actor.state == "empty":
			continue
		if actor.hit_rect().has_point(world_pos):
			return actor
	return null


func _station_post_at(world_pos: Vector2) -> String:
	for station_id in _station_post_rects.keys():
		if _station_post_rects[station_id].has_point(world_pos):
			return station_id
	return ""


## Ticket 13: the Sim.walkin_queue entry id under world_pos, for a Staffer
## drag's dinner-Stacking drop -- only a diner actually being served (has a
## live dinner Job) is ever a meaningful Stacking target, but that's
## Sim.can_stack_staffer_on_dinner()'s call to make, not this hit-test's; a
## diner still queued (no Job yet) is returned the same as one being served
## and simply rejected by that check, no rule duplicated here.
func _served_diner_at(world_pos: Vector2) -> int:
	for entry_id in _diner_actors.keys():
		var actor: DinerActor = _diner_actors[entry_id]
		if actor.hit_rect().has_point(world_pos):
			return int(entry_id)
	return -1


func _begin_staffer_drag(staffer_id: String, world_pos: Vector2) -> void:
	_drag_staffer_id = staffer_id
	_drag_start_world = world_pos
	_drag_preview = CharacterSprite.new()
	add_child(_drag_preview)
	_drag_preview.configure(BuildingLayout.resolve_character_sprite("staffer", staffer_id, "idle"))
	_drag_preview.modulate.a = 0.7
	_drag_preview.position = world_pos


## Shared by a Staffer drag and a guest drag (ticket 11) -- both just follow
## the pointer with a semi-transparent ghost sprite.
func _update_drag_preview(world_pos: Vector2) -> void:
	if _drag_preview != null:
		_drag_preview.position = world_pos


## Ends the in-progress Staffer drag/tap. A release that moved past the drag
## threshold tries, in order: a Station post drop (the existing
## Sim.assign_staffer() path -- the same reassignment/interruption semantics
## ui/station_card.gd's drop handling already used); a built Room bay drop
## (ticket 13, ADR-0008 -- Sim.can_stack_staffer_on_room()/
## stack_staffer_on_room(), Stacking this Staffer onto that Room's
## in-progress Housekeeping Job, no rule re-derived here); a served Terrace
## diner drop (same ticket -- Sim.can_stack_staffer_on_dinner()/
## stack_staffer_on_dinner() for that diner's in-progress dinner Job). None
## of the three landing is simply an abandoned drag, same as every other
## drag in this file that misses its target. An unmoved press emits
## staffer_tapped (a tap); no explicit "unassign" gesture exists, matching
## the old Control view.
func _end_staffer_drag(world_pos: Vector2) -> void:
	var staffer_id := _drag_staffer_id
	var moved := world_pos.distance_to(_drag_start_world) >= TAP_MOVEMENT_THRESHOLD

	_drag_staffer_id = ""
	if _drag_preview != null:
		_drag_preview.queue_free()
		_drag_preview = null

	if not moved:
		staffer_tapped.emit(staffer_id)
		return

	var station_id := _station_post_at(world_pos)
	if station_id != "":
		Sim.assign_staffer(staffer_id, station_id)
		return

	var bay := _tappable_room_bay_at(world_pos)
	if bay != null and bay.state == "built":
		if Sim.can_stack_staffer_on_room(staffer_id, bay.room_type_id, bay.instance_id):
			Sim.stack_staffer_on_room(staffer_id, bay.room_type_id, bay.instance_id)
		return

	var entry_id := _served_diner_at(world_pos)
	if entry_id != -1 and Sim.can_stack_staffer_on_dinner(staffer_id, entry_id):
		Sim.stack_staffer_on_dinner(staffer_id, entry_id)


## --- Guest tap/drag and seating (ticket 11, ADR-0001/0009) ---
##
## Same hand-rolled world-space-rect shape as the Staffer drag above, and
## the same tap-vs-drag threshold: a press on a lobby GuestActor always
## selects its Party immediately (_select_guest(), so the Needs bubble and
## every built bay's Match hint glow appear from the very first frame of a
## potential drag, per ADR-0009's "picking up a Party in a drag puts it into
## the same selected state a tap produces"). Release then decides what the
## press meant: moved past the threshold is a drop attempt against whatever
## built bay is under the pointer (_attempt_seat_drop()); an unmoved press
## on a guest whose Party was ALREADY selected before this press closes the
## bubble again (the ticket 10 toggle-shut gesture); an unmoved press that
## just opened a new selection leaves it open, since _select_guest() already
## did that work at press time.

func _begin_guest_drag(key: String, world_pos: Vector2) -> void:
	_drag_guest_key = key
	_drag_guest_start_world = world_pos
	_drag_guest_already_selected = _needs_bubble != null and _needs_bubble_key == key

	var actor: GuestActor = _lobby_guest_actors[key]
	var species_id: String = String(Sim.pending_party(actor.party_id).get("species_id", ""))
	_drag_preview = CharacterSprite.new()
	add_child(_drag_preview)
	_drag_preview.configure(BuildingLayout.resolve_character_sprite("guest", species_id, "idle"))
	_drag_preview.modulate.a = 0.7
	_drag_preview.position = world_pos

	_select_guest(key)


func _end_guest_drag(world_pos: Vector2) -> void:
	var key := _drag_guest_key
	var moved := world_pos.distance_to(_drag_guest_start_world) >= TAP_MOVEMENT_THRESHOLD
	var already_selected := _drag_guest_already_selected

	_drag_guest_key = ""
	if _drag_preview != null:
		_drag_preview.queue_free()
		_drag_preview = null

	if moved:
		_attempt_seat_drop(key, world_pos)
	elif already_selected:
		_close_needs_bubble()


## The drag half of the seating gesture: a release that moved past the
## threshold, dropped over a built Room bay whose Match hint for this Party
## isn't "none". Anything else -- released over a Build Slot, an empty
## shell, or open space -- is simply abandoned, same as every other drag in
## this file that misses its target; the guest stays put (a rebuild redraws
## it back at its lobby queue position on the next tick).
func _attempt_seat_drop(key: String, world_pos: Vector2) -> void:
	if not _lobby_guest_actors.has(key):
		return
	var party_id: int = _lobby_guest_actors[key].party_id
	var bay := _tappable_room_bay_at(world_pos)
	if bay == null or bay.state != "built":
		return
	var hint := BuildingLayout.room_bay_match_hint(party_id, bay.room_type_id, bay.instance_id)
	if hint == "none":
		return
	party_seat_attempted.emit(party_id, bay.room_type_id, bay.instance_id, hint)


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
	var available_height: float = maxf(viewport_size.y - hud_top_margin, 1.0)
	return minf(viewport_size.x / bounds.size.x, available_height / bounds.size.y)


## Eases the camera back to framing the whole building. Called on ready, on
## every floor unlock (bounds change), and from a HUD "fit all" control.
func ease_to_fit_all(duration: float = FIT_ALL_EASE_SECONDS) -> void:
	var floors := BuildingLayout.floors(GameState.rooms, GameState.stars)
	var bounds := BuildingLayout.fit_all_bounds(floors)
	_fit_all_zoom = _fit_zoom(bounds)
	var target_position: Vector2 = bounds.position + bounds.size / 2.0
	## Shifts the framing down by half the reserved margin's world-space
	## equivalent at this zoom -- when the strip's height is exactly what
	## _fit_zoom() above trimmed from available_height (the tall-building,
	## height-bound case), this lands the roofline exactly at
	## hud_top_margin on screen and the ground flush at the viewport's
	## bottom edge; when width binds instead (a short building), it's a
	## smaller partial nudge off dead-center, never a full recentre.
	target_position.y -= hud_top_margin / (2.0 * _fit_all_zoom)

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
			_last_pointer_screen = event.position
			if event.pressed:
				_on_press(get_global_mouse_position())
			else:
				_on_release(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		_last_pointer_screen = event.position
		if _drag_staffer_id != "" or _drag_guest_key != "":
			_update_drag_preview(get_global_mouse_position())
		elif _dragging:
			_pan_by(event.relative)
	elif event is InputEventMagnifyGesture:
		## factor > 1 is a pinch-out (fingers spreading -- "zoom in" intent),
		## which under this project's confirmed zoom convention means
		## multiplying zoom UP, not down.
		_zoom_by(event.factor)
	elif event is InputEventScreenTouch:
		_last_pointer_screen = event.position
		if event.pressed:
			_on_press(get_global_mouse_position())
		else:
			_on_release(get_global_mouse_position())
	elif event is InputEventScreenDrag:
		_last_pointer_screen = event.position
		if _drag_staffer_id != "" or _drag_guest_key != "":
			_update_drag_preview(get_global_mouse_position())
		else:
			_pan_by(event.relative)


## Shared press handler for a mouse-left-button or touch-down event: if it
## landed on a lobby guest or a Staffer, that starts that actor's own
## drag/tap instead of a camera pan (see the header comments above
## _staffer_at() and the guest tap/drag section).
func _on_press(world_pos: Vector2) -> void:
	var guest_key := _guest_key_at(world_pos)
	if guest_key != "":
		_begin_guest_drag(guest_key, world_pos)
		return

	## A Party is selected (ticket 11): a press on any Room bay is claimed
	## by the tap-then-tap half of the seating gesture, whether or not it's
	## actually a valid target -- a Build Slot or a "none"-hint Room while
	## selected does not respond to a tap at all (ui/hotel_panel.gd's
	## pre-existing _on_cell_pressed() rule under ADR-0001, unchanged here:
	## it is simply consumed with the selection left exactly as it was, not
	## treated as "elsewhere" and not falling through to the ordinary
	## build/inspect tap below). Anything else -- a Staffer, the
	## Terrace, or empty space -- closes the selection first and then falls
	## through to its own normal handling below, same as ticket 10's
	## "tapping elsewhere closes the bubble".
	if _selected_party_id != -1:
		var bay := _tappable_room_bay_at(world_pos)
		if bay != null:
			if bay.state == "built" and BuildingLayout.room_bay_match_hint(_selected_party_id, bay.room_type_id, bay.instance_id) != "none":
				_press_seat_bay_actor = bay
				_press_seat_bay_start_world = world_pos
			return
		_close_needs_bubble()

	var staffer_id := _staffer_at(world_pos)
	if staffer_id != "":
		_begin_staffer_drag(staffer_id, world_pos)
		return

	var bay := _tappable_room_bay_at(world_pos)
	if bay != null:
		_press_bay_actor = bay
		_press_bay_start_world = world_pos
		return

	if _terrace_tap_rect.has_point(world_pos):
		_press_terrace = true
		_press_terrace_start_world = world_pos
		return

	_dragging = true


func _on_release(world_pos: Vector2) -> void:
	if _drag_staffer_id != "":
		_end_staffer_drag(world_pos)
	elif _drag_guest_key != "":
		_end_guest_drag(world_pos)
	elif _press_seat_bay_actor != null:
		if world_pos.distance_to(_press_seat_bay_start_world) < TAP_MOVEMENT_THRESHOLD:
			var hint := BuildingLayout.room_bay_match_hint(_selected_party_id, _press_seat_bay_actor.room_type_id, _press_seat_bay_actor.instance_id)
			if hint != "none":
				party_seat_attempted.emit(_selected_party_id, _press_seat_bay_actor.room_type_id, _press_seat_bay_actor.instance_id, hint)
		_press_seat_bay_actor = null
	elif _press_bay_actor != null:
		if world_pos.distance_to(_press_bay_start_world) < TAP_MOVEMENT_THRESHOLD:
			room_slot_tapped.emit(_press_bay_actor.room_type_id, _press_bay_actor.instance_id)
		_press_bay_actor = null
	elif _press_terrace:
		if world_pos.distance_to(_press_terrace_start_world) < TAP_MOVEMENT_THRESHOLD:
			terrace_tapped.emit()
		_press_terrace = false
	else:
		_dragging = false


func _zoom_by(factor: float) -> void:
	var current_zoom: float = _camera.zoom.x
	var new_zoom: float = clampf(current_zoom * factor, _fit_all_zoom, MAX_ZOOM)
	_camera.zoom = Vector2(new_zoom, new_zoom)


func _pan_by(screen_delta: Vector2) -> void:
	_camera.position -= screen_delta / _camera.zoom


## Ticket 11: while a guest or Staffer drag is in progress, holding the
## pointer near the viewport's top or bottom edge pans the camera toward it
## at a steady rate -- see AUTO_PAN_EDGE_ZONE/AUTO_PAN_SPEED's comment.
## Division by _camera.zoom.y mirrors _pan_by()'s own screen-to-world
## conversion, so the pan reads as the same on-screen speed at any zoom.
func _auto_pan_if_near_edge(delta: float) -> void:
	var viewport_height := get_viewport_rect().size.y
	if viewport_height <= 0.0:
		return
	var world_delta: float = AUTO_PAN_SPEED * delta / _camera.zoom.y
	if _last_pointer_screen.y < AUTO_PAN_EDGE_ZONE:
		_camera.position.y -= world_delta
	elif _last_pointer_screen.y > viewport_height - AUTO_PAN_EDGE_ZONE:
		_camera.position.y += world_delta
