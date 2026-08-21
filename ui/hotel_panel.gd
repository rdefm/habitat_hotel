class_name HotelPanel
extends VBoxContainer

## Visual elevation of the hotel's built room instances, addressed by
## room_type_id + per-type instance_id (ADR-0004). One row (Floor) per
## unlocked Room type; a not-yet-unlocked Room type contributes no row at
## all. A Floor's row holds one cell per built instance plus a trailing
## Build Slot cell (instance_id -1) while it's still under its instance cap.
##
## Floor rows are added highest-unlock-star first (ties broken by id) --
## see _floor_sort_descending. ui/hotel_view.gd (ticket 02, ADR-0016) stacks
## this whole panel above Terrace/Reception, so this panel's own
## top-to-bottom order is what makes the *building's* bottom-to-top order
## read as ascending star, replacing the old flat alphabetical
## room_type_ids.sort().
##
## Two tap modes, switched by whether a Party is selected at Reception
## (ADR-0001, ticket 05): with no selected_party_id, tapping an
## empty/unlocked cell opens Build and tapping a built room opens Upgrade,
## exactly as before -- slot_selected lets the caller decide what to do.
## With a selected_party_id, every built-room cell instead shows its
## Sim.match_hint() (green/amber tint; a Build Slot or a "none" cell is
## never a seating target and does not respond to a tap at all) and tapping
## a green/amber cell emits seat_attempted instead, leaving Build/Upgrade
## unreachable until the caller clears the selection.
##
## Rows and cells are fully rebuilt on every refresh() rather than updated
## in place, since the set of visible Floors and built instances changes as
## the game progresses.
##
## Drag-and-drop (ticket 07, ADR-0009): each built-room cell is a
## RoomCellButton, a second, coexisting way to reach seat_attempted --
## dropping a Party card (ui/reception_panel.gd's PartyCardButton) resolves
## the same Sim.match_hint() the tap flow uses and, on a real match, emits
## seat_attempted exactly like _on_cell_pressed does, so main_screen's
## _on_seat_attempted handles both gestures identically without knowing
## which one fired. Unlike the tap flow, the dragged party_id doesn't come
## from selected_party_id -- it travels in the drag payload -- so a drop
## works regardless of Reception's current tap-selection. _can_drop_data
## does the real Build-Slot/none-match rejection (not just a type check) so
## that Godot's own drag-success bookkeeping -- which the dragged card reads
## via gui_is_drag_successful() -- reflects a genuine accept/reject rather
## than "some control caught it".
##
## Stacking (ticket 09, ADR-0008/0009): the same RoomCellButton also accepts
## a Staffer card (ui/staffer_card.gd's StafferCardButton) dropped onto a
## Room currently mid-clean, Stacking it onto that Housekeeping Job via
## Sim.can_stack_staffer_on_room()/stack_staffer_on_room() -- rejected (no
## state change, the dragged card's own reject-flash) for a Room with no
## in-flight Job at all or one already at Sim.STACK_CAP.

signal slot_selected(room_type_id: String, instance_id: int)
signal seat_attempted(party_id: int, room_type_id: String, instance_id: int, hint: String)

class RoomCellButton extends Button:
	signal drop_attempted(party_id: int, room_type_id: String, instance_id: int, hint: String)
	signal staffer_dropped(staffer_id: String, room_type_id: String, instance_id: int)

	var room_type_id: String = ""
	var instance_id: int = -1

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY:
			return false
		if disabled or instance_id == -1: # a Build Slot is never a seating or Stacking target
			return false
		match data.get("type"):
			"party":
				return Sim.match_hint(int(data["party_id"]), room_type_id, instance_id) != "none"
			"staffer":
				return Sim.can_stack_staffer_on_room(String(data["staffer_id"]), room_type_id, instance_id)
			_:
				return false

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		match data.get("type"):
			"party":
				var party_id: int = int(data["party_id"])
				var hint: String = Sim.match_hint(party_id, room_type_id, instance_id)
				drop_attempted.emit(party_id, room_type_id, instance_id, hint)
			"staffer":
				staffer_dropped.emit(String(data["staffer_id"]), room_type_id, instance_id)

const CELL_MIN_SIZE := Vector2(110, 88)
const ROW_MIN_HEIGHT := 112

const HINT_COLOR := {
	"green": Color(0.4, 1.0, 0.4),
	"amber": Color(1.0, 0.75, 0.3),
}
const NO_HINT_COLOR := Color(0.4, 0.4, 0.4)

@export var interactive: bool = false

## Set by the caller (main_screen) when a Party is selected at Reception;
## -1 means no Party is selected and normal Build/Upgrade tapping applies.
var selected_party_id: int = -1


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	refresh()
	EventBus.day_summary.connect(func(_s): refresh())
	EventBus.room_marked_dirty.connect(func(_t, _i): refresh())
	EventBus.room_cleaned.connect(func(_t, _i): refresh())


func refresh() -> void:
	for child in get_children():
		child.queue_free()

	var room_type_ids: Array = []
	for room_type_id in GameState.rooms.keys():
		if GameState.can_build_room_type(room_type_id):
			room_type_ids.append(room_type_id)
	room_type_ids.sort_custom(_floor_sort_descending)
	for room_type_id in room_type_ids:
		add_child(_make_floor_row(room_type_id))


func _floor_sort_descending(a: String, b: String) -> bool:
	var star_a: int = int(GameState.rooms[a]["unlock"]["star"])
	var star_b: int = int(GameState.rooms[b]["unlock"]["star"])
	if star_a != star_b:
		return star_a > star_b
	return a < b


func _make_floor_row(room_type_id: String) -> Control:
	var room_type: Dictionary = GameState.rooms[room_type_id]

	var floor_box := VBoxContainer.new()
	floor_box.add_theme_constant_override("separation", 2)

	var label := Label.new()
	label.text = room_type["name"]
	label.add_theme_font_size_override("font_size", 16)
	floor_box.add_child(label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, ROW_MIN_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	floor_box.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	scroll.add_child(row)

	var count := GameState.floor_instance_count(room_type_id)
	for instance_id in range(count):
		row.add_child(_make_cell(room_type_id, room_type, instance_id, GameState.room_instance(room_type_id, instance_id)))
	if GameState.can_build_more(room_type_id):
		row.add_child(_make_cell(room_type_id, room_type, -1, {}))

	return floor_box


func _make_cell(room_type_id: String, room_type: Dictionary, instance_id: int, room: Dictionary) -> Button:
	var btn := RoomCellButton.new()
	btn.room_type_id = room_type_id
	btn.instance_id = instance_id
	btn.custom_minimum_size = CELL_MIN_SIZE
	btn.toggle_mode = false
	btn.clip_text = true
	btn.pressed.connect(_on_cell_pressed.bind(room_type_id, instance_id))
	btn.drop_attempted.connect(_on_cell_dropped)
	btn.staffer_dropped.connect(_on_cell_staffer_dropped)

	if room.is_empty():
		btn.text = "%s\n(build)" % room_type["name"]
		btn.disabled = not interactive
		btn.modulate = NO_HINT_COLOR if selected_party_id != -1 else Color(1, 1, 1)
		btn.tooltip_text = ""
		return btn

	var occupied := room["occupant"] != null
	var dirty: bool = not occupied and bool(room.get("needs_cleaning", false))
	var upgrade_count: int = room.get("upgrades", []).size()
	var suffix := " ^%d" % upgrade_count if upgrade_count > 0 else ""
	var occupant_line := ""
	var modulate_color := Color(0.85, 0.95, 1.0)
	var tooltip := ""

	if occupied:
		var guest_name: String = room.get("occupant_name", "") if room.get("occupant_name", "") else "Guest"
		var species_id: String = room.get("occupant_species_id", "")
		var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
		var mismatch: bool = room.get("occupant_mismatch", false)
		var dinner_addon: bool = room.get("occupant_dinner_addon", false)
		var fit_text := "mismatch" if mismatch else "perfect fit"
		var addon_text := " + Dinner" if dinner_addon else ""
		occupant_line = "\n%s\n%s (%s)%s" % [guest_name, species_name, fit_text, addon_text]
		modulate_color = Color(1.0, 0.85, 0.5) if mismatch else Color(0.75, 1.0, 0.75)
		tooltip = "%s the %s -- %s%s" % [guest_name, species_name, fit_text, " -- expecting dinner service tonight" if dinner_addon else ""]
	elif dirty:
		occupant_line = "\n(cleaning)"
		modulate_color = Color(0.8, 0.75, 0.5)
		tooltip = "Being cleaned by housekeeping"

	btn.text = "%s #%d%s%s%s" % [room_type["name"], instance_id, suffix, occupant_line]
	btn.disabled = not interactive
	if selected_party_id != -1:
		var hint := Sim.match_hint(selected_party_id, room_type_id, instance_id)
		modulate_color = HINT_COLOR.get(hint, NO_HINT_COLOR)
	btn.modulate = modulate_color
	btn.tooltip_text = tooltip
	return btn


func _on_cell_pressed(room_type_id: String, instance_id: int) -> void:
	if selected_party_id != -1:
		if instance_id == -1:
			return # a Build Slot is never a seating target
		var hint := Sim.match_hint(selected_party_id, room_type_id, instance_id)
		if hint == "none":
			return # a no-highlight Room does not respond to a tap at all
		seat_attempted.emit(selected_party_id, room_type_id, instance_id, hint)
		return
	slot_selected.emit(room_type_id, instance_id)


func _on_cell_dropped(party_id: int, room_type_id: String, instance_id: int, hint: String) -> void:
	seat_attempted.emit(party_id, room_type_id, instance_id, hint)


func _on_cell_staffer_dropped(staffer_id: String, room_type_id: String, instance_id: int) -> void:
	Sim.stack_staffer_on_room(staffer_id, room_type_id, instance_id)
