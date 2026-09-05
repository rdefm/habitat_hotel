class_name StationPanel
extends VBoxContainer

## Reception/Housekeeping Station slots, always visible near Reception
## (ticket 04, ADR-0009) -- relocated out of the Roster menu,
## which no longer does Station assignment at all now that ticket 05 moved
## Kitchen onto the Terrace's modal too (ui/terrace_menu.gd); the Roster
## menu is retired entirely in ticket 06. Tap a Staffer actor then a Station
## to (re)assign them there, mirroring Reception's tap-Party/tap-Room flow --
## same Sim.assign_staffer() call and interruption semantics the old Roster
## menu used, via the shared StationCard widget (ui/terrace_menu.gd uses the
## same one for Kitchen) so both places stay in lockstep.
##
## main_screen.gd calls refresh() when the generic overlay closes, since a
## Kitchen (re)assignment made there (still routed through Sim.assign_staffer())
## can move a Staffer off one of these Stations without this panel's own
## taps ever firing.
##
## Tapping a Staffer actor still toggles selection for the tap-Station-to-
## assign gesture above, and now also emits staffer_tapped so main_screen can
## open the bespoke detail popup (ticket 06, ADR-0011) -- replacing the
## retired ui/roster_menu.gd as the place to see a Staffer's Skill/Traits.
##
## Actor reskin + Staff Pool (ticket 03, ADR-0016): each of these Stations
## is now a zone -- StationCard's existing drop-target/tap-to-assign button
## (unchanged, still shared with terrace_menu.gd) plus a row of
## compact standing tokens for its currently-assigned Staffers, built by
## _make_actor() below. Every Staffer with no Station at all
## (GameState.staffer_station() == "") renders the same way in a new Staff
## Pool row instead. Both rows are recomputed from live GameState queries on
## every refresh(), so assigning a Pool Staffer to a Station (or moving them
## between Stations) automatically moves their token between rows -- there's
## no separate "unassign" call to wire, since Sim's existing
## assign_staffer()/reassign_staffer() are the only ways a Staffer's Station
## ever changes and both already trigger refresh() via _on_assigned().
##
## _make_actor() instantiates StafferCard's StafferCardButton inner class
## directly rather than calling StafferCard.make_button() -- that keeps the
## drag payload/reject-flash behavior (and, via StafferCard.skill_summary()/
## current_label(), the same text) shared with terrace_menu.gd's Kitchen row,
## while giving this panel its own compact, actor-sized visuals instead of
## make_button()'s wide info card (which terrace_menu.gd still uses as-is;
## that Kitchen-staffing row is out of this ticket's scope). ui/actor_style.gd
## strips the engine's default bevelled Button chrome down to a flat,
## rounded shape so a tinted token reads as a standing character rather than
## a UI button, per ADR-0015/0016's "plain colored shapes" actors.

const StafferCard = preload("res://ui/staffer_card.gd")
const StationCard = preload("res://ui/station_card.gd")
const ActorStyle = preload("res://ui/actor_style.gd")

## The Stations this panel shows: every Station except Kitchen, which
## ticket 05 moved onto the Terrace's own modal (ui/terrace_menu.gd).
## Bellhop was a third card here until ADR-0019 removed the Station.
const STATION_IDS := ["reception", "housekeeping"]
const ACTOR_MIN_SIZE := Vector2(40, 56)

## Emitted whenever a Staffer actor is tapped, selected or not, so
## main_screen can open their detail popup.
signal staffer_tapped(staffer_id: String)

var _selected_staffer_id: String = ""

var _station_row: HBoxContainer
var _pool_row: HBoxContainer
var _wage_label: Label

## station_id -> its zone Control, populated by refresh() -- lets
## ui/staff_job_travel_layer.gd (ticket 09) find a live "home" anchor
## position for a Housekeeping Staffer's travel without hardcoding layout.
var _zone_by_station: Dictionary = {}


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var station_header := Label.new()
	station_header.text = "Stations -- drag a Staffer onto one to assign, or tap a Staffer then tap a Station"
	add_child(station_header)

	_station_row = HBoxContainer.new()
	_station_row.add_theme_constant_override("separation", 12)
	add_child(_station_row)

	var pool_header := Label.new()
	pool_header.text = "Staff Pool -- unassigned Staffers"
	add_child(pool_header)

	var pool_scroll := ScrollContainer.new()
	pool_scroll.custom_minimum_size = Vector2(0, ACTOR_MIN_SIZE.y + 8)
	pool_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	pool_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(pool_scroll)

	_pool_row = HBoxContainer.new()
	_pool_row.add_theme_constant_override("separation", 2)
	pool_scroll.add_child(_pool_row)

	_wage_label = Label.new()
	_wage_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var wage := int(GameState.balance.get("costs", {}).get("staff_wage_per_day", 0))
	_wage_label.text = "Your crew costs a flat %d cash/day, deducted every Night phase regardless of Station." % wage
	add_child(_wage_label)

	refresh()


func refresh() -> void:
	for child in _station_row.get_children():
		child.queue_free()
	for child in _pool_row.get_children():
		child.queue_free()

	_zone_by_station.clear()
	for station_id in STATION_IDS:
		var zone := _make_zone(station_id)
		_zone_by_station[station_id] = zone
		_station_row.add_child(zone)

	var pool_ids: Array = []
	for staffer_id in GameState.staffers.keys():
		if GameState.staffer_station(staffer_id) == "":
			pool_ids.append(staffer_id)
	pool_ids.sort()

	if pool_ids.is_empty():
		_pool_row.add_child(_label("(everyone's assigned)"))
	for staffer_id in pool_ids:
		_pool_row.add_child(_make_actor(staffer_id))


## Read-only lookup for ui/staff_job_travel_layer.gd (ticket 09): the
## Control whose live get_global_rect() is a Housekeeping Staffer's "home"
## position to travel from/back to. Returns null if refresh() hasn't run yet
## or station_id isn't one of STATION_IDS.
func find_zone(station_id: String) -> Control:
	return _zone_by_station.get(station_id)


func _make_zone(station_id: String) -> Control:
	var zone := VBoxContainer.new()
	zone.add_theme_constant_override("separation", 2)
	zone.add_child(StationCard.make_button(station_id, _selected_staffer_id, _on_assigned))

	var assigned: Array = GameState.station_staffers(station_id)
	if not assigned.is_empty():
		var token_row := HBoxContainer.new()
		token_row.add_theme_constant_override("separation", 2)
		for staffer_id in assigned:
			token_row.add_child(_make_actor(staffer_id))
		zone.add_child(token_row)

	return zone


func _make_actor(staffer_id: String) -> Button:
	var staffer: Dictionary = GameState.staffers[staffer_id]
	var selected := staffer_id == _selected_staffer_id

	var btn := StafferCard.StafferCardButton.new()
	btn.staffer_id = staffer_id
	btn.custom_minimum_size = ACTOR_MIN_SIZE
	btn.clip_text = true
	btn.text = "%s%s" % ["»\n" if selected else "", String(staffer["name"]).left(3)]
	btn.add_theme_stylebox_override("normal", ActorStyle.flat_box())
	btn.add_theme_stylebox_override("hover", ActorStyle.flat_box())
	btn.add_theme_stylebox_override("pressed", ActorStyle.flat_box())
	btn.add_theme_stylebox_override("focus", ActorStyle.flat_box())
	btn.modulate = Color(1.0, 1.0, 0.6) if selected else Color(1, 1, 1)
	btn.tooltip_text = "%s -- %s -- currently %s" % [staffer["name"], StafferCard.skill_summary(staffer_id), StafferCard.current_label(staffer_id)]
	btn.pressed.connect(_on_staffer_pressed.bind(staffer_id))
	return btn


func _on_staffer_pressed(staffer_id: String) -> void:
	_selected_staffer_id = "" if _selected_staffer_id == staffer_id else staffer_id
	refresh()
	staffer_tapped.emit(staffer_id)


func _on_assigned() -> void:
	_selected_staffer_id = ""
	refresh()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l
