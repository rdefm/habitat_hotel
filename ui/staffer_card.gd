class_name StafferCard
extends RefCounted

## Shared Staffer card builder (ADR-0009): a tappable card showing a
## Staffer's per-Station Skill summary and current Station, highlighted
## while selected. Tapping calls on_pressed(staffer_id) so the caller (which
## owns the "which Staffer is selected" state) can toggle selection and
## refresh. Shared by ui/station_panel.gd and ui/terrace_menu.gd, both of
## which also emit their own staffer_tapped signal off the same tap so
## main_screen can open the bespoke detail popup (ticket 06, ADR-0011).
##
## Drag-and-drop (ticket 08, ADR-0009): the returned button is a
## StafferCardButton, a second, coexisting way to reach
## Sim.assign_staffer() -- dragging it onto a Station card (see
## ui/station_card.gd's StationCardButton) assigns staffer_id there,
## independent of tap-selection, mirroring ticket 07's
## PartyCardButton/RoomCellButton split in ui/reception_panel.gd and
## ui/hotel_panel.gd. A plain click still fires `pressed` (Godot only starts
## a drag once the pointer clears its move threshold, so click and drag
## never both fire for one gesture).

const Station = preload("res://sim/station.gd")

const MIN_SIZE := Vector2(120, 100)

## Drag source for a Staffer card. _can_drop_data/_drop_data live on
## StationCard's StationCardButton (ui/station_card.gd), which does the
## actual Sim.assign_staffer() call -- so gui_is_drag_successful() here
## already reflects a real accept/reject, not just "some control caught
## it". _dragging guards against reacting to a notification meant for an
## unrelated drag.
class StafferCardButton extends Button:
	var staffer_id: String = ""
	var _dragging: bool = false

	func _get_drag_data(_at_position: Vector2) -> Variant:
		_dragging = true
		var preview := Label.new()
		preview.text = text
		preview.modulate = modulate
		set_drag_preview(preview)
		return {"type": "staffer", "staffer_id": staffer_id}

	func _notification(what: int) -> void:
		if what == NOTIFICATION_DRAG_END and _dragging:
			_dragging = false
			if not get_viewport().gui_is_drag_successful():
				_flash_rejected()

	func _flash_rejected() -> void:
		var base := modulate
		var tween := create_tween()
		tween.tween_property(self, "modulate", Color(1.0, 0.3, 0.3), 0.1)
		tween.tween_property(self, "modulate", base, 0.2)


static func make_button(staffer_id: String, selected: bool, on_pressed: Callable) -> Button:
	var staffer: Dictionary = GameState.staffers[staffer_id]
	var skills: Dictionary = staffer["skills"]
	var current_station := GameState.staffer_station(staffer_id)
	var current_label: String = Station.LABELS.get(current_station, "(unassigned)")
	var skill_summary := "R%d B%d H%d K%d" % [
		int(skills["reception"]), int(skills["bellhop"]), int(skills["housekeeping"]), int(skills["kitchen"]),
	]

	var btn := StafferCardButton.new()
	btn.staffer_id = staffer_id
	btn.custom_minimum_size = MIN_SIZE
	btn.clip_text = true
	btn.text = "%s%s\n%s\n%s" % ["» " if selected else "", staffer["name"], skill_summary, current_label]
	btn.modulate = Color(1.0, 1.0, 0.6) if selected else Color(1, 1, 1)
	btn.tooltip_text = "%s -- %s -- currently %s" % [staffer["name"], skill_summary, current_label]
	btn.pressed.connect(on_pressed.bind(staffer_id))
	return btn
