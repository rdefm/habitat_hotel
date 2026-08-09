class_name StafferCard
extends RefCounted

## Shared Staffer card builder (ADR-0009): a tappable card showing a
## Staffer's per-Station Skill summary and current Station, highlighted
## while selected. Tapping calls on_pressed(staffer_id) so the caller (which
## owns the "which Staffer is selected" state) can toggle selection and
## refresh. Shared by ui/station_panel.gd, ui/terrace_menu.gd, and
## ui/roster_menu.gd (the latter renders it disabled, read-only).

const Station = preload("res://sim/station.gd")

const MIN_SIZE := Vector2(120, 100)


static func make_button(staffer_id: String, selected: bool, on_pressed: Callable) -> Button:
	var staffer: Dictionary = GameState.staffers[staffer_id]
	var skills: Dictionary = staffer["skills"]
	var current_station := GameState.staffer_station(staffer_id)
	var current_label: String = Station.LABELS.get(current_station, "(unassigned)")
	var skill_summary := "R%d B%d H%d K%d" % [
		int(skills["reception"]), int(skills["bellhop"]), int(skills["housekeeping"]), int(skills["kitchen"]),
	]

	var btn := Button.new()
	btn.custom_minimum_size = MIN_SIZE
	btn.clip_text = true
	btn.text = "%s%s\n%s\n%s" % ["» " if selected else "", staffer["name"], skill_summary, current_label]
	btn.modulate = Color(1.0, 1.0, 0.6) if selected else Color(1, 1, 1)
	btn.tooltip_text = "%s -- %s -- currently %s" % [staffer["name"], skill_summary, current_label]
	btn.pressed.connect(on_pressed.bind(staffer_id))
	return btn
