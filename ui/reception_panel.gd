class_name ReceptionPanel
extends VBoxContainer

## The Reception queue (ticket 05, ADR-0001): every Sim.pending_arrivals
## entry rendered as a tappable card showing Species and party size at a
## glance, plus its Patience tier (calm/impatient/huffy -- see
## sim/patience_state.gd) so the player gets fair warning before a Party
## walks away. Tapping a card selects that Party (tapping it again, or
## tapping any other card, changes/clears the selection); main_screen reads
## selected_party_id via party_selected and drives HotelPanel's seating
## highlight from it -- this panel never touches Sim directly beyond the
## read-only pending_arrivals/match queries, same as every other UI file's
## relationship to GameState.
##
## Rebuilt on every refresh() rather than updated in place (same tradeoff
## HotelPanel makes) since Patience needs to visibly tick down live: this
## panel refreshes on every EventBus.tick_advanced, not just on queue-
## membership-changing events.
##
## dinner_addon_selected (ticket 12): while a Party is selected, a checkbox
## lets the player opt that Party into a dinner add-on before tapping a
## Room. main_screen reads this public field at the moment it calls
## Sim.seat_party()/opens SeatConfirmMenu. Selecting a card seeds it from
## Sim.pending_party()'s own dinner_addon field rather than defaulting to
## false -- the opt-in is a Party-level choice that Sim.seat_party() already
## sticks onto the Party dict across a split-across-Rooms seating (see its
## doc comment), so re-selecting a partially-seated Party's remainder here
## reflects that it's already opted in instead of silently forgetting it.
##
## Drag-and-drop (ticket 07, ADR-0009): each card is a PartyCardButton, which
## coexists with the tap-select flow above rather than replacing it -- a
## plain click still fires `pressed` (Godot only starts a drag once the
## pointer moves past its threshold, so click and drag never both fire for
## one gesture). Dropping on a Room is validated and actioned entirely by
## HotelPanel's RoomCellButton against the dragged party_id, independent of
## _selected_party_id; this panel only needs to hand out that id and react
## if the drop is rejected.

const PatienceState = preload("res://sim/patience_state.gd")

## Drag source for a Reception card. _can_drop_data/_drop_data live on
## HotelPanel's RoomCellButton (ui/hotel_panel.gd), which does the real
## Sim.match_hint() validation -- so gui_is_drag_successful() here already
## reflects a real rejection (Build Slot / none-match / dropped outside the
## grid alike), not just "some control happened to catch it". _dragging
## guards against reacting to a notification meant for an unrelated drag.
class PartyCardButton extends Button:
	var party_id: int = -1
	var _dragging: bool = false

	func _get_drag_data(_at_position: Vector2) -> Variant:
		_dragging = true
		var preview := Label.new()
		preview.text = text
		preview.modulate = modulate
		set_drag_preview(preview)
		return {"type": "party", "party_id": party_id}

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

signal party_selected(party_id: int)

const CARD_MIN_SIZE := Vector2(150, 64)

const TIER_COLOR := {
	"calm": Color(0.85, 0.95, 1.0),
	"impatient": Color(1.0, 0.75, 0.35),
	"huffy": Color(1.0, 0.45, 0.4),
}

var _selected_party_id: int = -1
var dinner_addon_selected: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 4)
	refresh()
	EventBus.tick_advanced.connect(func(_d, _t): refresh())
	EventBus.phase_changed.connect(func(_d, _p): refresh())


## Deselects (if anything was selected) and rebuilds. Called by main_screen
## once a seat attempt resolves, so a just-(fully-)seated or walked-away
## Party's stale card selection can't linger.
func clear_selection() -> void:
	_selected_party_id = -1
	dinner_addon_selected = false
	refresh()


func refresh() -> void:
	if _selected_party_id != -1 and Sim.pending_party(_selected_party_id).is_empty():
		_selected_party_id = -1
		party_selected.emit(-1)

	for child in get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "Reception"
	header.add_theme_font_size_override("font_size", 16)
	add_child(header)

	if Sim.pending_arrivals.is_empty():
		add_child(_label("No one waiting."))
		return

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, CARD_MIN_SIZE.y + 8)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	scroll.add_child(row)

	for party in Sim.pending_arrivals:
		row.add_child(_make_card(party))

	if _selected_party_id != -1:
		add_child(_make_dinner_addon_check())


func _make_card(party: Dictionary) -> Button:
	var party_id := int(party["id"])
	var species_id: String = party["species_id"]
	var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
	var tier := PatienceState.tier(float(party["patience"]), GameState.balance["patience"])
	var selected := party_id == _selected_party_id

	var btn := PartyCardButton.new()
	btn.party_id = party_id
	btn.custom_minimum_size = CARD_MIN_SIZE
	btn.clip_text = true
	btn.text = "%s%s\n%d guest(s)\n%s" % [
		"» " if selected else "", species_name, int(party["party_size"]), tier.capitalize(),
	]
	var color: Color = TIER_COLOR[tier]
	btn.modulate = color.lightened(0.3) if selected else color
	btn.tooltip_text = "%s the %s -- needs %s" % [party["name"], species_name, String(", ").join(party["needs"])]
	btn.pressed.connect(_on_card_pressed.bind(party_id))
	return btn


func _make_dinner_addon_check() -> CheckBox:
	var check := CheckBox.new()
	check.text = "Add dinner service for this stay"
	check.button_pressed = dinner_addon_selected
	check.toggled.connect(func(value: bool): dinner_addon_selected = value)
	return check


func _on_card_pressed(party_id: int) -> void:
	_selected_party_id = -1 if _selected_party_id == party_id else party_id
	dinner_addon_selected = false if _selected_party_id == -1 else bool(Sim.pending_party(_selected_party_id).get("dinner_addon", false))
	party_selected.emit(_selected_party_id)
	refresh()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	return l
