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
##
## Drag-and-drop (ticket 08, ADR-0009): the returned button is a
## StationCardButton, which also accepts a Staffer dropped onto it (see
## ui/staffer_card.gd's StafferCardButton) and routes it through the same
## Sim.assign_staffer()/on_assigned pair the tap flow above uses -- so
## green/no-op routing is identical for both gestures by construction, same
## as ticket 07's RoomCellButton/PartyCardButton split. Any Staffer is a
## valid drop here (there's no Party/Room-style match_hint to reject on);
## the button's own `disabled` (gating the tap flow while no Staffer is
## tap-selected) doesn't affect drop hit-testing, so a drag works
## regardless of tap-selection state.

const Station = preload("res://sim/station.gd")

const MIN_SIZE := Vector2(120, 100)

class StationCardButton extends Button:
	signal staffer_dropped(staffer_id: String)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.get("type") == "staffer"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		staffer_dropped.emit(String(data["staffer_id"]))


static func make_button(station_id: String, selected_staffer_id: String, on_assigned: Callable) -> Button:
	var staffer_ids: Array = GameState.station_staffers(station_id)
	var names := []
	for staffer_id in staffer_ids:
		names.append(String(GameState.staffers.get(staffer_id, {}).get("name", staffer_id)))

	var btn := StationCardButton.new()
	btn.custom_minimum_size = MIN_SIZE
	btn.clip_text = true
	btn.text = "%s\n%s" % [Station.LABELS[station_id], String("\n").join(names) if not names.is_empty() else "(empty)"]
	btn.modulate = Color(1.0, 0.75, 0.75) if names.is_empty() else Color(0.85, 1.0, 0.85)
	btn.disabled = selected_staffer_id == ""
	btn.pressed.connect(func():
		Sim.assign_staffer(selected_staffer_id, station_id)
		on_assigned.call()
	)
	btn.staffer_dropped.connect(func(staffer_id: String):
		Sim.assign_staffer(staffer_id, station_id)
		on_assigned.call()
	)
	return btn
