class_name StationCard
extends RefCounted

## Shared Station-slot card builder (ADR-0009): a tappable card showing
## station_id's currently assigned Staffer names, disabled while no Staffer
## is selected. Tapping it (re)assigns selected_staffer_id there via
## Sim.assign_staffer() -- the single Staffer<->Station reassignment path,
## which already treats "tap the Station they're already at" and unknown ids
## as harmless no-ops and already interrupts only the moved Staffer's own
## in-flight job -- then calls on_assigned so the caller can clear its own
## selection and refresh. Shared by ui/station_panel.gd
## (Reception/Bellhop/Housekeeping, ticket 04) and ui/terrace_menu.gd
## (Kitchen, ticket 05).

const Station = preload("res://sim/station.gd")

const MIN_SIZE := Vector2(120, 100)


static func make_button(station_id: String, selected_staffer_id: String, on_assigned: Callable) -> Button:
	var staffer_ids: Array = GameState.station_staffers(station_id)
	var names := []
	for staffer_id in staffer_ids:
		names.append(String(GameState.staffers.get(staffer_id, {}).get("name", staffer_id)))

	var btn := Button.new()
	btn.custom_minimum_size = MIN_SIZE
	btn.clip_text = true
	btn.text = "%s\n%s" % [Station.LABELS[station_id], String("\n").join(names) if not names.is_empty() else "(empty)"]
	btn.modulate = Color(1.0, 0.75, 0.75) if names.is_empty() else Color(0.85, 1.0, 0.85)
	btn.disabled = selected_staffer_id == ""
	btn.pressed.connect(func():
		Sim.assign_staffer(selected_staffer_id, station_id)
		on_assigned.call()
	)
	return btn
