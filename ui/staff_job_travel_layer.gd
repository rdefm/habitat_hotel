class_name StaffJobTravelLayer
extends Control

## Staff Job travel animation (ticket 09, ADR-0016): generalizes
## ui/lobby_view.gd's old decorative, disconnected Housekeeping/Kitchen
## round-trips into real point-to-point travel tied to actual sim state,
## mirroring ui/room_occupancy_layer.gd's guest-walk-in treatment. A
## Housekeeping Staffer who claims a dirty Room's cleaning Job travels from
## the Housekeeping Station zone (ui/station_panel.gd) to that Room's real
## cell and stands there until the Job resolves, then travels back. A
## Kitchen Staffer who claims a breakfast/dinner Job does the same between
## the Terrace structure and the real Diner actor (ui/terrace_panel.gd) they're
## serving. lobby_view.gd's own housekeeper round-trip is retired by this
## ticket in favor of this file.
##
## Housekeeping/Kitchen Jobs model cleaning/serving *work* time, not travel
## time -- there's no separate "en route" tick count to drive a movement
## fraction against. So travel here is a fixed-duration one-shot Tween for
## each leg (mirroring room_occupancy_layer.gd's own
## CHECKIN_WALK_DURATION/CHECKOUT_WALK_DURATION trips), with the
## Staffer simply standing at the target for the (possibly long) remainder of
## the Job's ticks_remaining in between -- matching the ticket's own "travels
## ... and remains there until the Job completes, then returns" wording.
##
## Detecting completion vs. interruption: Sim exposes no per-Job start/end
## signal for Housekeeping/Kitchen (unlike guest_seated/guest_checked_out),
## so this polls every tick_advanced instead, same as
## room_occupancy_layer.gd's own _on_tick_advanced()/_advance_walk() do for
## walk-ins. A tracked Staffer whose Job entry (Sim.cleaning_job()/
## breakfast_job()/dinner_job()) has disappeared this tick is resolved
## (played as a return trip) if their target actually cleared -- the Room's
## needs_cleaning flipped false, or the queue entry is gone -- and interrupted
## (freed immediately, no return trip) otherwise, since sim_controller.gd's
## _drop_staffer_jobs() (reassignment/Stacking-elsewhere) erases a Job entry
## without ever clearing its target. Stacking a second Staffer onto an
## already-claimed Job (ADR-0008) needs no special case: it's just another
## staffer_id independently discovered mid-Job by the same per-tick sweep.
##
## Lives as a screen-space overlay sibling of ui/room_occupancy_layer.gd/
## ui/toast_layer.gd in main_screen's tree (mouse_filter IGNORE, never
## intercepts a tap/drag) rather than inside station_panel.gd/terrace_panel.gd,
## since both those panels' zones/queue rows can rebuild out from under a
## parented child (see room_occupancy_layer.gd's own class doc for why this
## overlay-plus-live-lookup shape is this codebase's answer to that).

const ActorStyle = preload("res://ui/actor_style.gd")
const HotelPanel = preload("res://ui/hotel_panel.gd")
const StationPanel = preload("res://ui/station_panel.gd")
const TerracePanel = preload("res://ui/terrace_panel.gd")

const ACTOR_SIZE := Vector2(32, 46)
const TRAVEL_DURATION := 0.5

## Set by main_screen before/after this node enters the tree -- read lazily
## rather than cached, matching room_occupancy_layer.gd's/toast_layer.gd's
## own convention so a later panel rebuild is always reflected.
var hotel_panel: HotelPanel
var station_panel: StationPanel
var terrace_panel: TerracePanel

## staffer_id -> {kind: "housekeeping"/"breakfast"/"dinner", node: Control,
## state: "to_target" (mid-outbound-Tween) or "at_target" (parked, repinned
## every frame), plus room_type_id+instance_id (housekeeping) or entry_id
## (breakfast/dinner)}.
var _travel: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	EventBus.tick_advanced.connect(_on_tick_advanced)
	set_process(true)


## Keeps every parked (already-arrived) Staffer glued to its live target
## position every rendered frame -- a Staffer still mid-outbound-Tween is left
## alone here since the Tween itself owns its position for that leg, the same
## split room_occupancy_layer.gd draws between a settled occupant and a guest
## mid-walk into their Room.
func _process(_delta: float) -> void:
	for staffer_id in _travel:
		var entry: Dictionary = _travel[staffer_id]
		if entry["state"] != "at_target":
			continue
		var target_ctrl := _target_control(entry)
		if target_ctrl == null:
			continue
		entry["node"].position = _to_local(target_ctrl.get_global_rect().get_center()) - ACTOR_SIZE / 2.0


func _on_tick_advanced(_day: int, _tick_in_day: int) -> void:
	_sync_housekeeping()
	_sync_kitchen()


## --- Housekeeping ---

func _sync_housekeeping() -> void:
	var active: Dictionary = {}
	for staffer_id in GameState.station_staffers("housekeeping"):
		var job := Sim.cleaning_job(staffer_id)
		if job.is_empty():
			continue
		active[staffer_id] = true
		var target_info := {"room_type_id": job["room_type_id"], "instance_id": int(job["instance_id"])}
		if not _travel.has(staffer_id) or not _same_target(_travel[staffer_id], "housekeeping", target_info):
			_start_travel(staffer_id, "housekeeping", target_info)

	for staffer_id in _travel.keys().duplicate():
		var entry: Dictionary = _travel[staffer_id]
		if entry["kind"] != "housekeeping" or active.has(staffer_id):
			continue
		var room := GameState.room_instance(entry["room_type_id"], entry["instance_id"])
		var resolved: bool = room.is_empty() or not bool(room.get("needs_cleaning", false))
		_end_travel(staffer_id, resolved)


## --- Kitchen (breakfast and dinner share one Station/claim model, ADR-0005:
## _kitchen_busy() means a given Staffer is only ever mid-breakfast XOR
## mid-dinner, never both at once) ---

func _sync_kitchen() -> void:
	var active: Dictionary = {}
	for staffer_id in GameState.station_staffers("kitchen"):
		var bjob := Sim.breakfast_job(staffer_id)
		if not bjob.is_empty():
			active[staffer_id] = true
			var target_info := {"entry_id": int(bjob["entry_id"])}
			if not _travel.has(staffer_id) or not _same_target(_travel[staffer_id], "breakfast", target_info):
				_start_travel(staffer_id, "breakfast", target_info)
			continue
		var djob := Sim.dinner_job(staffer_id)
		if not djob.is_empty():
			active[staffer_id] = true
			var target_info := {"entry_id": int(djob["entry_id"])}
			if not _travel.has(staffer_id) or not _same_target(_travel[staffer_id], "dinner", target_info):
				_start_travel(staffer_id, "dinner", target_info)

	for staffer_id in _travel.keys().duplicate():
		var entry: Dictionary = _travel[staffer_id]
		var kind: String = entry["kind"]
		if (kind != "breakfast" and kind != "dinner") or active.has(staffer_id):
			continue
		var resolved: bool
		if kind == "breakfast":
			resolved = Sim.breakfast_entry(int(entry["entry_id"])).is_empty()
		else:
			resolved = Sim.walkin_entry(int(entry["entry_id"])).is_empty()
		_end_travel(staffer_id, resolved)


## --- Travel lifecycle ---

## True iff entry (an existing _travel value) already targets kind+target_info
## -- the "nothing changed, leave the outbound/parked Tween alone" case both
## _sync_housekeeping()/_sync_kitchen() check before calling _start_travel().
## Comparing kind alone isn't enough: sim_controller.gd's
## stack_staffer_on_room()/_on_breakfast()/_on_dinner() all unconditionally
## _drop_staffer_jobs() first, even for "a same-Station Job on a different
## target" (its own doc comment's example), so a Staffer already mid-Job can
## be Stacked straight onto a *different* Room/queue-entry of the same kind --
## that has to re-trigger travel to the new target, not get treated as
## already-there.
func _same_target(entry: Dictionary, kind: String, target_info: Dictionary) -> bool:
	if entry["kind"] != kind:
		return false
	for key in target_info:
		if entry.get(key) != target_info[key]:
			return false
	return true


## Starts staffer_id's outbound leg from their Station's home position to the
## real target described by target_info. Frees any stale entry first -- for a
## same-tick Station-to-Station handoff (defensive only) and for a genuine
## mid-Job retarget (_same_target() above returning false while a Job is
## still in flight) alike -- so this never leaves an orphaned actor node
## floating at the old target. Kills the stale entry's own Tween before
## freeing its node: create_tween() binds a Tween's lifetime to *this*
## overlay (the caller of create_tween()), not to the node it animates, so an
## un-killed Tween would keep trying to drive a freed node's position.
func _start_travel(staffer_id: String, kind: String, target_info: Dictionary) -> void:
	_free_stale_entry(staffer_id)

	var entry: Dictionary = {"kind": kind, "state": "to_target"}
	for key in target_info:
		entry[key] = target_info[key]

	var home := _home_anchor(kind)
	var node := _make_staffer_token(staffer_id, kind)
	node.position = home - ACTOR_SIZE / 2.0
	add_child(node)
	entry["node"] = node
	_travel[staffer_id] = entry

	var target_ctrl := _target_control(entry)
	var to := _to_local(target_ctrl.get_global_rect().get_center()) if target_ctrl != null else home

	var tween := create_tween()
	entry["tween"] = tween
	tween.tween_property(node, "position", to - ACTOR_SIZE / 2.0, TRAVEL_DURATION)
	tween.tween_callback(func():
		if _travel.has(staffer_id) and _travel[staffer_id]["node"] == node:
			_travel[staffer_id]["state"] = "at_target"
	)


## Shared by _start_travel()'s stale-entry cleanup and _end_travel()'s
## interrupted case: kills entry's own in-flight Tween (see _start_travel()'s
## doc for why that's necessary) before freeing its node.
func _free_stale_entry(staffer_id: String) -> void:
	if not _travel.has(staffer_id):
		return
	var stale: Dictionary = _travel[staffer_id]
	var tween: Tween = stale.get("tween")
	if tween != null and tween.is_valid():
		tween.kill()
	stale["node"].queue_free()
	_travel.erase(staffer_id)


## Ends staffer_id's tracked travel. A resolved Job (the ticket's "then
## returns") plays a return Tween from wherever the actor currently stands
## back to its Station's home before freeing it; an interrupted one (the
## ticket's "interrupts their travel immediately") frees it on the spot --
## station_panel.gd's/terrace_menu.gd's own live roster token already shows
## the Staffer at their new Station or the Staff Pool by the time this runs,
## since both always reflect GameState.staffer_station() directly.
func _end_travel(staffer_id: String, resolved: bool) -> void:
	if not resolved:
		_free_stale_entry(staffer_id)
		return

	var entry: Dictionary = _travel[staffer_id]
	var node: Control = entry["node"]
	var outbound_tween: Tween = entry.get("tween")
	if outbound_tween != null and outbound_tween.is_valid():
		outbound_tween.kill() # in case the Job resolved before the outbound leg ever finished
	_travel.erase(staffer_id)

	var home := _home_anchor(entry["kind"])
	var tween := create_tween()
	tween.tween_property(node, "position", home - ACTOR_SIZE / 2.0, TRAVEL_DURATION)
	tween.tween_callback(node.queue_free)


## --- Anchors ---

## A Housekeeping Staffer's home is the always-visible Housekeeping Station
## zone on the Reception floor; a Kitchen Staffer's is the Terrace structure
## itself, since Kitchen's own Station zone only exists inside
## ui/terrace_menu.gd's modal (ADR-0010) rather than anywhere on the
## permanently visible spatial view -- mirroring how room_occupancy_layer.gd
## anchors a guest's check-in walk on Reception's own rect rather than a
## dedicated entrance node.
func _home_anchor(kind: String) -> Vector2:
	if kind == "housekeeping":
		if station_panel == null:
			return Vector2.ZERO
		var zone := station_panel.find_zone("housekeeping")
		return _to_local(zone.get_global_rect().get_center()) if zone != null else Vector2.ZERO
	if terrace_panel == null:
		return Vector2.ZERO
	return _to_local(terrace_panel.get_global_rect().get_center())


func _target_control(entry: Dictionary) -> Control:
	match entry["kind"]:
		"housekeeping":
			return hotel_panel.find_room_cell(entry["room_type_id"], entry["instance_id"]) if hotel_panel != null else null
		"breakfast":
			return terrace_panel.find_breakfast_entry(entry["entry_id"]) if terrace_panel != null else null
		"dinner":
			return terrace_panel.find_dinner_entry(entry["entry_id"]) if terrace_panel != null else null
	return null


func _to_local(global_pos: Vector2) -> Vector2:
	return global_pos - global_position


## --- Actor token ---

const KIND_COLOR := {
	"housekeeping": Color(0.3, 0.55, 0.5),
	"breakfast": Color(0.85, 0.6, 0.3),
	"dinner": Color(0.85, 0.6, 0.3),
}


func _make_staffer_token(staffer_id: String, kind: String) -> Control:
	var staffer: Dictionary = GameState.staffers.get(staffer_id, {})
	var staffer_name: String = String(staffer.get("name", staffer_id))

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = ACTOR_SIZE
	panel.size = ACTOR_SIZE
	panel.add_theme_stylebox_override("panel", ActorStyle.flat_box())
	panel.modulate = KIND_COLOR.get(kind, Color(1, 1, 1))
	panel.tooltip_text = "%s -- working a %s Job" % [staffer_name, kind.capitalize()]

	var label := Label.new()
	label.text = staffer_name.left(3)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel
