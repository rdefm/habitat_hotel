class_name RosterMenu
extends VBoxContainer

## Kitchen Station assignment (ticket 04/08, ADR-0001/0005/0009): tap a
## Staffer card then tap the Kitchen card to (re)assign them there, mirroring
## Reception's tap-Party/tap-Room flow (reception_panel.gd/hotel_panel.gd).
## Reception/Bellhop/Housekeeping Station slots moved out to
## ui/station_panel.gd, always visible near Reception (ticket 04); Kitchen
## stays here until ticket 05 moves it onto the Terrace, at which point this
## menu is retired entirely (ticket 06).
## Sim.assign_staffer() already treats "tap the Station they're already at"
## and unknown ids as harmless no-ops, and already interrupts only the
## moved Staffer's own in-flight job (ticket 07) -- this view just re-taps
## re-renders both sides after every assignment. Shares its Staffer/Station
## card rendering with ui/station_panel.gd via ui/staffer_card.gd and
## ui/station_card.gd.
##
## Kitchen's card is disabled while no Staffer is selected: unlike a Room
## cell, a Station has no other action to fall back to.

const StafferCard = preload("res://ui/staffer_card.gd")
const StationCard = preload("res://ui/station_card.gd")

var _selected_staffer_id: String = ""

var _staffer_row: HBoxContainer
var _station_row: HBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(560, 220)
	add_theme_constant_override("separation", 10)

	var staffer_header := Label.new()
	staffer_header.text = "Staffers -- tap one, then tap Kitchen to assign"
	add_child(staffer_header)

	_staffer_row = HBoxContainer.new()
	_staffer_row.add_theme_constant_override("separation", 8)
	add_child(_staffer_row)

	var station_header := Label.new()
	station_header.text = "Stations"
	add_child(station_header)

	_station_row = HBoxContainer.new()
	_station_row.add_theme_constant_override("separation", 8)
	add_child(_station_row)

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

	_station_row.add_child(StationCard.make_button("kitchen", _selected_staffer_id, _on_assigned))


func _on_staffer_pressed(staffer_id: String) -> void:
	_selected_staffer_id = "" if _selected_staffer_id == staffer_id else staffer_id
	refresh()


func _on_assigned() -> void:
	_selected_staffer_id = ""
	refresh()
