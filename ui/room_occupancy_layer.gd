class_name RoomOccupancyLayer
extends Control

## Room floor reskin (ticket 04, ADR-0016): turns the abstract "elevator"
## fade-out stand-in guest_seated used to get from ui/lobby_view.gd into a
## real point-to-point walk from the Reception floor to the actual Room cell
## a seated Party landed on, plus a persistent guest actor standing in that
## cell for the whole stay. lobby_view.gd's guest_seated handling (and its
## matching decorative bellhop round-trip) is removed by this ticket in
## favor of this file; turned-away/checked-out are covered by ticket 05
## below, while room-dirty (the housekeeper's own travel) stays
## lobby_view.gd's job until ticket 09 replaces it too.
##
## Ticket 05 extends this same overlay with the symmetric reverse trips:
## guest_checked_out walks a Room's persistent occupant actor back down to
## Reception and despawns it there (replacing the old
## room_marked_dirty-triggered instant despawn -- room_marked_dirty always
## follows guest_checked_out for the same Room, per sim_controller.gd's
## _checkout_guest(), so this file no longer needs to listen for it at all),
## and guest_turned_away walks a waiting Party's actor from its real
## Reception queue card back out and despawns it. Both are one-shot tweens
## from a live-captured start position rather than continuously re-anchored
## like an in-flight walk-in or a settled occupant, since neither has a
## later sim event that would need to find the actor again mid-flight.
##
## Lives as a screen-space overlay sibling *above* HotelView in
## main_screen's tree (mouse_filter IGNORE, so it never intercepts a tap/drag
## meant for a RoomCellButton beneath it) rather than inside any one panel's
## own Control tree, because HotelPanel.refresh() fully tears down and
## rebuilds every Room cell on room_marked_dirty/room_cleaned/day_summary
## (see hotel_panel.gd's own class doc) -- parenting a mid-flight or
## whole-stay-long actor *inside* a cell would get it queue_free()'d out from
## under itself the moment an unrelated Room finished cleaning. Instead every
## actor here lives in this overlay's own coordinate space and is
## repositioned from HotelPanel.find_room_cell()'s current on-screen rect
## every frame (occupants) or every tick (in-transit walkers) -- correct
## across scrolling and across HotelPanel's rebuilds alike, and reads to the
## player as "the guest is standing in the cell" even though it isn't
## literally that cell's scene-tree child.
##
## Escort accompaniment (ADR-0014/0017): progress is driven by comparing each
## tick's Sim.escort_job(staffer_id)["ticks_remaining"] against the value
## first observed for that job, not a real-seconds Tween -- ticks already
## pause/scale with Clock exactly the way the underlying Escort itself does,
## so this can't drift out of sync with the sim the way a wall-clock tween
## driving a pausable, speed-variable countdown would. The unstaffed flat
## delay has no per-Staffer job to track progress against at all, so that
## case idles the guest at Reception and only plays a fixed-duration walk
## once checking_in actually resolves, matching the ticket's "plays after
## that delay" (not stretched across it) wording -- and with no Bellhop
## actor ever created, since escort_mode is false for that whole wait.

const ActorStyle = preload("res://ui/actor_style.gd")
const HotelPanel = preload("res://ui/hotel_panel.gd")
const ReceptionPanel = preload("res://ui/reception_panel.gd")
const MatchHint = preload("res://sim/match_hint.gd")

const ACTOR_SIZE := Vector2(36, 52)
const GUEST_TRAVEL_OFFSET := Vector2(-14, 0)
const BELLHOP_TRAVEL_OFFSET := Vector2(14, 0)
const UNSTAFFED_WALK_DURATION := 0.8
const CHECKOUT_WALK_DURATION := 0.8
const TURN_AWAY_WALK_DURATION := 0.8
## How far outside Reception's own rect the "entrance" a turned-away Party
## walks out through sits -- there's no dedicated entrance node in the
## spatial view (ADR-0016), so this is a fixed offset from Reception's own
## live rect rather than a second panel reference.
const ENTRANCE_OFFSET_X := 80.0

## Set by main_screen before/after this node enters the tree -- read lazily
## (find_room_cell()/get_global_rect() calls) rather than cached, so a later
## HotelPanel/ReceptionPanel rebuild is always reflected.
var hotel_panel: HotelPanel
var reception_panel: ReceptionPanel

## room_key -> {guest, bellhop (or null), staffer_id (or ""), initial_ticks,
## room_type_id, instance_id} -- an in-flight walk-in not yet arrived.
var _walking: Dictionary = {}

## room_key -> {guest, room_type_id, instance_id} -- a Room's persistent
## occupant actor for the rest of their stay.
var _occupants: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	EventBus.guest_seated.connect(_on_guest_seated)
	EventBus.guest_checked_out.connect(_on_guest_checked_out)
	EventBus.guest_turned_away.connect(_on_guest_turned_away)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	set_process(true)


## Keeps every already-arrived occupant glued to its Room cell's live
## position every rendered frame -- cheap for this game's room counts, and
## the only way to stay correct across scrolling and HotelPanel rebuilds
## alike without caching a Control reference refresh() could free. Also
## keeps a still-waiting walker (parked at Reception -- either queued for a
## free Bellhop, or sitting out the unstaffed flat delay) glued to
## Reception's live position the same way; a walker already mid-Escort is
## left alone here since _advance_escort() (tick-driven, not frame-driven)
## owns its position for that stretch.
func _process(_delta: float) -> void:
	if hotel_panel == null:
		return
	for key in _occupants:
		var occ: Dictionary = _occupants[key]
		var cell := hotel_panel.find_room_cell(occ["room_type_id"], occ["instance_id"])
		if cell == null:
			continue
		occ["guest"].position = _to_local(cell.get_global_rect().get_center()) - ACTOR_SIZE / 2.0

	for key in _walking:
		var entry: Dictionary = _walking[key]
		if entry["bellhop"] == null:
			entry["guest"].position = _reception_anchor() - ACTOR_SIZE / 2.0


func _on_guest_seated(guest_name: String, species_id: String, room_type_id: String, instance_id: int, mismatch: bool) -> void:
	var key := _room_key(room_type_id, instance_id)
	if _walking.has(key) or _occupants.has(key):
		return # a Room can't admit a second Party mid-stay -- defensive only

	var guest := _make_guest(guest_name, species_id, mismatch)
	guest.position = _reception_anchor() - ACTOR_SIZE / 2.0
	add_child(guest)

	_walking[key] = {
		"guest": guest, "bellhop": null, "staffer_id": "", "initial_ticks": 1,
		"room_type_id": room_type_id, "instance_id": instance_id,
	}


## Fires exactly at checkout (see sim_controller.gd's _checkout_guest()),
## before that same call clears the Room's occupant and emits
## room_marked_dirty -- claims the persistent occupant actor out of
## _occupants here so a later room_marked_dirty/HotelPanel.refresh() rebuild
## can't free it out from under this walk. Also cancels a still-in-flight
## walk-in for the same key -- can't happen today (a stay's first night
## doesn't resolve until well after any walk-in animation completes), but
## staying defensive here (as _on_guest_seated's own key-collision guard
## already does) keeps a hypothetical orphaned walker from permanently
## blocking that Room from ever being re-seated.
func _on_guest_checked_out(_guest_name: String, _species_id: String, room_type_id: String, instance_id: int) -> void:
	var key := _room_key(room_type_id, instance_id)
	if _walking.has(key):
		_cancel_walk(key)
		return
	if not _occupants.has(key): # defensive -- checkout should always follow a tracked occupant
		return
	var occ: Dictionary = _occupants[key]
	_occupants.erase(key)
	_play_checkout_walk(occ["guest"])


func _play_checkout_walk(guest: Control) -> void:
	var target := _reception_anchor() - ACTOR_SIZE / 2.0
	var tween := create_tween()
	tween.tween_property(guest, "position", target, CHECKOUT_WALK_DURATION)
	tween.tween_callback(guest.queue_free)


## reception_panel.gd's queue hasn't rebuilt for this tick yet when this
## runs -- sim_controller.gd (an autoload) connects to EventBus.tick_advanced
## in its own _ready(), which always registers before any UI node's, so its
## _decay_patience() -> guest_turned_away chain fully resolves (including
## this listener) before reception_panel's own tick_advanced-triggered
## refresh() gets a turn. That's what lets _turn_away_start_position() below
## read the Party's real, still-live queue card instead of a fixed stand-in.
func _on_guest_turned_away(guest_name: String, species_id: String, reason: String, party_id: int) -> void:
	var guest := _make_turned_away_guest(guest_name, species_id, reason)
	guest.position = _turn_away_start_position(party_id) - ACTOR_SIZE / 2.0
	add_child(guest)

	var tween := create_tween()
	tween.tween_property(guest, "position", _entrance_anchor() - ACTOR_SIZE / 2.0, TURN_AWAY_WALK_DURATION)
	tween.tween_callback(guest.queue_free)


func _turn_away_start_position(party_id: int) -> Vector2:
	if reception_panel != null:
		var card := reception_panel.find_party_card(party_id)
		if card != null:
			return _to_local(card.get_global_rect().get_center())
	# Defensive only -- per this function's caller's doc comment, the
	# ordering guarantee means card should always be found; this falls back
	# to the general Reception anchor (the "fixed stand-in" the ticket asks
	# this overlay to avoid) only if that guarantee is ever broken.
	return _reception_anchor()


func _on_tick_advanced(_day: int, _tick_in_day: int) -> void:
	for key in _walking.keys().duplicate():
		_advance_walk(key)


func _advance_walk(key: String) -> void:
	var entry: Dictionary = _walking[key]
	var room := GameState.room_instance(entry["room_type_id"], entry["instance_id"])
	if room.is_empty():
		_cancel_walk(key)
		return

	if room.get("checking_in", false):
		if room.get("escort_mode", false):
			_advance_escort(entry)
		# unstaffed: idle at Reception until checking_in resolves -- nothing to animate yet
		return

	_arrive(key, entry)


## Staffed Bellhop branch: travel is driven by the claiming Staffer's own
## Escort Job ticking down, not a real-seconds Tween -- see this file's
## class doc for why.
func _advance_escort(entry: Dictionary) -> void:
	var staffers := Sim.escort_staffers(entry["room_type_id"], entry["instance_id"])
	if staffers.is_empty():
		if entry["bellhop"] != null:
			entry["bellhop"].queue_free()
			entry["bellhop"] = null
			entry["staffer_id"] = ""
		return # still waiting for a free Bellhop -- guest stays parked at Reception

	var staffer_id: String = staffers[0]
	var ticks_remaining := int(Sim.escort_job(staffer_id).get("ticks_remaining", 0))
	if entry["staffer_id"] != staffer_id:
		entry["staffer_id"] = staffer_id
		entry["initial_ticks"] = maxi(1, ticks_remaining)
		if entry["bellhop"] == null:
			entry["bellhop"] = _make_bellhop(staffer_id)
			add_child(entry["bellhop"])

	var cell := hotel_panel.find_room_cell(entry["room_type_id"], entry["instance_id"]) if hotel_panel != null else null
	if cell == null:
		return

	var fraction := clampf(1.0 - (float(ticks_remaining) / float(entry["initial_ticks"])), 0.0, 1.0)
	var from := _reception_anchor()
	var to := _to_local(cell.get_global_rect().get_center())
	var pos := from.lerp(to, fraction)
	entry["guest"].position = pos + GUEST_TRAVEL_OFFSET - ACTOR_SIZE / 2.0
	entry["bellhop"].position = pos + BELLHOP_TRAVEL_OFFSET - ACTOR_SIZE / 2.0


func _arrive(key: String, entry: Dictionary) -> void:
	if entry["bellhop"] != null:
		entry["bellhop"].queue_free()

	var guest: Control = entry["guest"]
	var cell := hotel_panel.find_room_cell(entry["room_type_id"], entry["instance_id"]) if hotel_panel != null else null
	if cell != null:
		var target := _to_local(cell.get_global_rect().get_center()) - ACTOR_SIZE / 2.0
		if entry["staffer_id"] == "": # unstaffed: no stretched travel happened yet -- play the walk now
			var tween := create_tween()
			tween.tween_property(guest, "position", target, UNSTAFFED_WALK_DURATION)
		else:
			guest.position = target
	# else: leave the guest wherever it was -- _process's occupant loop will
	# snap it to the real cell the moment find_room_cell() finds one.

	_walking.erase(key)
	_occupants[key] = {"guest": guest, "room_type_id": entry["room_type_id"], "instance_id": entry["instance_id"]}


func _cancel_walk(key: String) -> void:
	var entry: Dictionary = _walking[key]
	entry["guest"].queue_free()
	if entry["bellhop"] != null:
		entry["bellhop"].queue_free()
	_walking.erase(key)


## Reuses sim_controller.gd's own room-addressing key (also what
## Sim.escort_staffers() keys off internally) rather than inventing a second
## room_type_id+instance_id format.
func _room_key(room_type_id: String, instance_id: int) -> String:
	return MatchHint.room_key({"room_type_id": room_type_id, "instance_id": instance_id})


func _reception_anchor() -> Vector2:
	if reception_panel == null:
		return Vector2.ZERO
	return _to_local(reception_panel.get_global_rect().get_center())


## See ENTRANCE_OFFSET_X's doc -- a fixed offset outside Reception's own live
## rect, rather than a dedicated entrance node.
func _entrance_anchor() -> Vector2:
	if reception_panel == null:
		return Vector2.ZERO
	var rect := reception_panel.get_global_rect()
	return _to_local(Vector2(rect.position.x - ENTRANCE_OFFSET_X, rect.get_center().y))


func _to_local(global_pos: Vector2) -> Vector2:
	return global_pos - global_position


func _make_guest(guest_name: String, species_id: String, mismatch: bool) -> Control:
	var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
	var token := _make_token(species_name.left(3), Color(1.0, 0.85, 0.5) if mismatch else Color(0.75, 1.0, 0.75))
	token.tooltip_text = "%s the %s -- %s" % [guest_name, species_name, ("mismatch" if mismatch else "perfect fit")]
	return token


func _make_turned_away_guest(guest_name: String, species_id: String, reason: String) -> Control:
	var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
	var token := _make_token(species_name.left(3), Color(0.85, 0.4, 0.4))
	token.tooltip_text = "%s the %s -- turned away (%s)" % [guest_name, species_name, reason]
	return token


func _make_bellhop(staffer_id: String) -> Control:
	var staffer: Dictionary = GameState.staffers.get(staffer_id, {})
	var staffer_name: String = String(staffer.get("name", staffer_id))
	var token := _make_token(staffer_name.left(3), Color(0.85, 0.7, 0.4))
	token.tooltip_text = "%s -- escorting a guest to their Room" % staffer_name
	return token


func _make_token(caption: String, color: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = ACTOR_SIZE
	panel.size = ACTOR_SIZE
	panel.add_theme_stylebox_override("panel", ActorStyle.flat_box())
	panel.modulate = color

	var label := Label.new()
	label.text = caption
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
