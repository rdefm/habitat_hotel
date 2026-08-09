class_name RosterMenu
extends VBoxContainer

## Read-only Staffer roster (ticket 05, ADR-0009): Kitchen Station
## assignment moved onto the Terrace's modal (ui/terrace_menu.gd), joining
## ticket 04's relocation of Reception/Bellhop/Housekeeping to
## ui/station_panel.gd -- so this menu no longer does Station assignment
## anywhere. What's left is each Staffer's per-Station Skill summary and
## current assignment via the shared ui/staffer_card.gd, disabled since
## there's nothing to tap into here yet. Retired entirely once ticket 06
## replaces this view with the tap-to-open Staffer detail popup (ADR-0011).

const StafferCard = preload("res://ui/staffer_card.gd")

var _staffer_row: HBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(560, 160)
	add_theme_constant_override("separation", 10)

	var header := Label.new()
	header.text = "Staffers"
	add_child(header)

	_staffer_row = HBoxContainer.new()
	_staffer_row.add_theme_constant_override("separation", 8)
	add_child(_staffer_row)

	refresh()


func refresh() -> void:
	for child in _staffer_row.get_children():
		child.queue_free()

	var staffer_ids := GameState.staffers.keys()
	staffer_ids.sort()
	for staffer_id in staffer_ids:
		var card := StafferCard.make_button(staffer_id, false, func(_id): pass)
		card.disabled = true
		_staffer_row.add_child(card)
