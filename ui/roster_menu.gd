class_name RosterMenu
extends VBoxContainer

## Roster & Station assignment (ticket 08, ADR-0001/0005): tap a Staffer
## card then tap a Station card to (re)assign them there, mirroring
## Reception's tap-Party/tap-Room flow (reception_panel.gd/hotel_panel.gd).
## Sim.assign_staffer() already treats "tap the Station they're already at"
## and unknown ids as harmless no-ops, and already interrupts only the
## moved Staffer's own in-flight job (ticket 07) -- this view just re-tap
## re-renders both sides after every assignment.
##
## Station cards are disabled while no Staffer is selected: unlike a Room
## cell, a Station has no other action to fall back to.

const Station = preload("res://sim/station.gd")

const CARD_MIN_SIZE := Vector2(120, 100)

const STATION_LABELS := {
	"reception": "Reception",
	"bellhop": "Bellhop",
	"housekeeping": "Housekeeping",
	"kitchen": "Kitchen",
}

var _selected_staffer_id: String = ""

var _staffer_row: HBoxContainer
var _station_row: HBoxContainer
var _wage_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(560, 320)
	add_theme_constant_override("separation", 10)

	var staffer_header := Label.new()
	staffer_header.text = "Staffers -- tap one, then tap a Station to assign"
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
		_staffer_row.add_child(_make_staffer_card(staffer_id))

	for station_id in Station.IDS:
		_station_row.add_child(_make_station_card(station_id))


func _make_staffer_card(staffer_id: String) -> Button:
	var staffer: Dictionary = GameState.staffers[staffer_id]
	var skills: Dictionary = staffer["skills"]
	var current_station := GameState.staffer_station(staffer_id)
	var current_label: String = STATION_LABELS.get(current_station, "(unassigned)")
	var selected := staffer_id == _selected_staffer_id
	var skill_summary := _skill_summary(skills)

	var btn := Button.new()
	btn.custom_minimum_size = CARD_MIN_SIZE
	btn.clip_text = true
	btn.text = "%s%s\n%s\n%s" % ["» " if selected else "", staffer["name"], skill_summary, current_label]
	btn.modulate = Color(1.0, 1.0, 0.6) if selected else Color(1, 1, 1)
	btn.tooltip_text = "%s -- %s -- currently %s" % [staffer["name"], skill_summary, current_label]
	btn.pressed.connect(_on_staffer_pressed.bind(staffer_id))
	return btn


## "R# B# H# K#" -- shared by the card face and its tooltip.
func _skill_summary(skills: Dictionary) -> String:
	return "R%d B%d H%d K%d" % [
		int(skills["reception"]), int(skills["bellhop"]), int(skills["housekeeping"]), int(skills["kitchen"]),
	]


func _make_station_card(station_id: String) -> Button:
	var staffer_ids: Array = GameState.station_staffers(station_id)
	var names := []
	for staffer_id in staffer_ids:
		names.append(String(GameState.staffers.get(staffer_id, {}).get("name", staffer_id)))

	var btn := Button.new()
	btn.custom_minimum_size = CARD_MIN_SIZE
	btn.clip_text = true
	btn.text = "%s\n%s" % [STATION_LABELS[station_id], String("\n").join(names) if not names.is_empty() else "(empty)"]
	btn.modulate = Color(1.0, 0.75, 0.75) if names.is_empty() else Color(0.85, 1.0, 0.85)
	btn.disabled = _selected_staffer_id == ""
	btn.pressed.connect(_on_station_pressed.bind(station_id))
	return btn


func _on_staffer_pressed(staffer_id: String) -> void:
	_selected_staffer_id = "" if _selected_staffer_id == staffer_id else staffer_id
	refresh()


func _on_station_pressed(station_id: String) -> void:
	Sim.assign_staffer(_selected_staffer_id, station_id)
	_selected_staffer_id = ""
	refresh()
