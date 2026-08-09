class_name StationPanel
extends VBoxContainer

## Reception/Bellhop/Housekeeping Station slots, always visible near
## Reception (ticket 04, ADR-0009) -- relocated out of the Roster menu,
## which now handles only Kitchen (ui/roster_menu.gd) until ticket 05 moves
## that onto the Terrace too, at which point the Roster menu is retired
## entirely (ticket 06). Tap a Staffer card then a Station card to
## (re)assign them there, mirroring Reception's tap-Party/tap-Room flow --
## same Sim.assign_staffer() call and interruption semantics the old Roster
## menu used, via the StafferCard/StationCard widgets shared with
## ui/roster_menu.gd so both places stay in lockstep.
##
## main_screen.gd calls refresh() when the generic overlay closes, since a
## Kitchen (re)assignment made there (still routed through Sim.assign_staffer())
## can move a Staffer off one of these three Stations without this panel's
## own taps ever firing.

const StafferCard = preload("res://ui/staffer_card.gd")
const StationCard = preload("res://ui/station_card.gd")

const STATION_IDS := ["reception", "bellhop", "housekeeping"]

var _selected_staffer_id: String = ""

var _staffer_row: HBoxContainer
var _station_row: HBoxContainer
var _wage_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var staffer_header := Label.new()
	staffer_header.text = "Staffers -- tap one, then tap a Station to assign"
	add_child(staffer_header)

	_staffer_row = HBoxContainer.new()
	_staffer_row.add_theme_constant_override("separation", 8)
	add_child(_staffer_row)

	_station_row = HBoxContainer.new()
	_station_row.add_theme_constant_override("separation", 8)
	add_child(_station_row)

	_wage_label = Label.new()
	_wage_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	var wage := int(GameState.balance.get("costs", {}).get("staff_wage_per_day", 0))
	_wage_label.text = "Your crew costs a flat %d cash/day, deducted every Night phase regardless of Station." % wage
	add_child(_wage_label)

	refresh()


func refresh() -> void:
	for child in _staffer_row.get_children():
		child.queue_free()
	for child in _station_row.get_children():
		child.queue_free()

	var staffer_ids := GameState.staffers.keys()
	staffer_ids.sort()
	for staffer_id in staffer_ids:
		_staffer_row.add_child(StafferCard.make_button(staffer_id, staffer_id == _selected_staffer_id, _on_staffer_pressed))

	for station_id in STATION_IDS:
		_station_row.add_child(StationCard.make_button(station_id, _selected_staffer_id, _on_assigned))


func _on_staffer_pressed(staffer_id: String) -> void:
	_selected_staffer_id = "" if _selected_staffer_id == staffer_id else staffer_id
	refresh()


func _on_assigned() -> void:
	_selected_staffer_id = ""
	refresh()
