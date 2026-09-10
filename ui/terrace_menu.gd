class_name TerraceMenu
extends VBoxContainer

## The Terrace's modal (ticket 05, ADR-0009/0010): Kitchen Station staffing
## -- tap a Staffer card then tap the Kitchen card to (re)assign, the same
## Sim.assign_staffer() call and interruption semantics the world's own
## Station posts use for Reception/Housekeeping (ADR-0020, ticket 07) --
## the Daily Special picker, and the Terrace's own Upgrade list (reusing
## UpgradeMenu's purchase-row pattern (tickets 03/13) but addressed by the
## Terrace's single fixed structure instead of room_type_id + instance_id).
##
## The current Daily Special and the breakfast/dinner queues (with
## Patience) live ambiently in ui/hotel_world.gd's own Terrace band instead
## (ADR-0020) -- this modal only holds the *interactive* pieces.
##
## Opened by tapping the Terrace structure (main_screen._on_terrace_tapped
## -> open_menu()), which pauses the Clock like every other generic-overlay
## menu -- so this view doesn't need its own tick_advanced refresh wiring.
##
## Tapping the Kitchen Staffer row still toggles selection for the tap-
## Station-to-assign gesture, and now also emits staffer_tapped so
## main_screen can layer the bespoke detail popup (ticket 06, ADR-0011) on
## top of this modal via PopupHost.
##
## The Staffer/Station card builders below (_make_staffer_button()/
## _make_station_button()) were shared with ui/station_panel.gd via
## ui/staffer_card.gd/ui/station_card.gd until ticket 17 retired that whole
## Control-tree view -- this was their only other caller, so their logic
## moved here rather than surviving as a two-caller-turned-one-caller shared
## file (ADR-0020's world already reimplements the Reception/Housekeeping
## half of this gesture on its own Station posts).

const Station = preload("res://sim/station.gd")

## Emitted whenever a Staffer card is tapped, selected or not, so
## main_screen can open their detail popup.
signal staffer_tapped(staffer_id: String)

var _selected_staffer_id: String = ""

var _staffer_row: HBoxContainer
var _station_row: HBoxContainer
var _special_option: OptionButton
var _species_ids_by_option_index: Array = []
var _stats_label: Label
var _purchased_list: VBoxContainer
var _available_list: VBoxContainer


func _ready() -> void:
	custom_minimum_size = Vector2(560, 480)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	body.add_child(_section_header("Kitchen Staffing -- tap a Staffer, then tap Kitchen to assign"))
	_staffer_row = HBoxContainer.new()
	_staffer_row.add_theme_constant_override("separation", 8)
	body.add_child(_staffer_row)
	_station_row = HBoxContainer.new()
	_station_row.add_theme_constant_override("separation", 8)
	body.add_child(_station_row)

	body.add_child(_section_header("Daily Special"))
	body.add_child(_build_special_row())

	body.add_child(_section_header("Terrace Upgrades"))
	_stats_label = Label.new()
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.add_child(_stats_label)

	var purchased_header := Label.new()
	purchased_header.text = "Purchased:"
	body.add_child(purchased_header)
	_purchased_list = VBoxContainer.new()
	body.add_child(_purchased_list)

	var available_header := Label.new()
	available_header.text = "Available:"
	body.add_child(available_header)
	_available_list = VBoxContainer.new()
	body.add_child(_available_list)

	_refresh()


func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l


## --- Kitchen staffing (moved off ui/roster_menu.gd; ticket 17 inlined the
## Staffer/Station card builders off the retired ui/staffer_card.gd/
## ui/station_card.gd -- see the class doc) ---

const CARD_MIN_SIZE := Vector2(120, 100)

## Drag source for a Staffer card. _can_drop_data/_drop_data live on
## StationCardButton below, which does the actual Sim.assign_staffer()
## call -- so gui_is_drag_successful() here already reflects a real
## accept/reject, not just "some control caught it". _dragging guards
## against reacting to a notification meant for an unrelated drag.
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


## Accepts a Staffer dropped onto it (see StafferCardButton above) and
## routes it through the same Sim.assign_staffer()/_on_assigned() pair the
## tap flow uses, so green/no-op routing is identical for both gestures by
## construction.
class StationCardButton extends Button:
	signal staffer_dropped(staffer_id: String)

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return typeof(data) == TYPE_DICTIONARY and data.get("type") == "staffer"

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		staffer_dropped.emit(String(data["staffer_id"]))


static func _staffer_skill_summary(staffer_id: String) -> String:
	var skills: Dictionary = GameState.staffers[staffer_id]["skills"]
	return "R%d H%d K%d" % [
		int(skills["reception"]), int(skills["housekeeping"]), int(skills["kitchen"]),
	]


static func _staffer_current_label(staffer_id: String) -> String:
	return Station.LABELS.get(GameState.staffer_station(staffer_id), "(unassigned)")


func _make_staffer_button(staffer_id: String, selected: bool) -> Button:
	var staffer: Dictionary = GameState.staffers[staffer_id]
	var summary := _staffer_skill_summary(staffer_id)
	var label := _staffer_current_label(staffer_id)

	var btn := StafferCardButton.new()
	btn.staffer_id = staffer_id
	btn.custom_minimum_size = CARD_MIN_SIZE
	btn.clip_text = true
	btn.text = "%s%s\n%s\n%s" % ["» " if selected else "", staffer["name"], summary, label]
	btn.modulate = Color(1.0, 1.0, 0.6) if selected else Color(1, 1, 1)
	btn.tooltip_text = "%s -- %s -- currently %s" % [staffer["name"], summary, label]
	btn.pressed.connect(_on_staffer_pressed.bind(staffer_id))
	return btn


func _make_station_button(station_id: String) -> Button:
	var staffer_ids: Array = GameState.station_staffers(station_id)
	var names := []
	for staffer_id in staffer_ids:
		names.append(String(GameState.staffers.get(staffer_id, {}).get("name", staffer_id)))

	var btn := StationCardButton.new()
	btn.custom_minimum_size = CARD_MIN_SIZE
	btn.clip_text = true
	btn.text = "%s\n%s" % [Station.LABELS[station_id], String("\n").join(names) if not names.is_empty() else "(empty)"]
	btn.modulate = Color(1.0, 0.75, 0.75) if names.is_empty() else Color(0.85, 1.0, 0.85)
	btn.disabled = _selected_staffer_id == ""
	btn.pressed.connect(func():
		Sim.assign_staffer(_selected_staffer_id, station_id)
		_on_assigned()
	)
	btn.staffer_dropped.connect(func(staffer_id: String):
		Sim.assign_staffer(staffer_id, station_id)
		_on_assigned()
	)
	return btn


func _refresh_kitchen() -> void:
	for child in _staffer_row.get_children():
		child.queue_free()
	for child in _station_row.get_children():
		child.queue_free()

	var staffer_ids := GameState.staffers.keys()
	staffer_ids.sort()
	for staffer_id in staffer_ids:
		_staffer_row.add_child(_make_staffer_button(staffer_id, staffer_id == _selected_staffer_id))

	_station_row.add_child(_make_station_button("kitchen"))


func _on_staffer_pressed(staffer_id: String) -> void:
	_selected_staffer_id = "" if _selected_staffer_id == staffer_id else staffer_id
	_refresh_kitchen()
	staffer_tapped.emit(staffer_id)


func _on_assigned() -> void:
	_selected_staffer_id = ""
	_refresh_kitchen()


## --- Daily Special (ticket 10 built where the choice lives; this is the UI) ---

func _build_special_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	_special_option = OptionButton.new()
	_species_ids_by_option_index = [""]
	_special_option.add_item("(none)")
	var species_ids := GameState.species.keys()
	species_ids.sort()
	for species_id in species_ids:
		_species_ids_by_option_index.append(species_id)
		_special_option.add_item(String(GameState.species[species_id].get("name", species_id)))
	_special_option.selected = maxi(0, _species_ids_by_option_index.find(GameState.daily_special))
	_special_option.item_selected.connect(_on_special_selected)
	row.add_child(_special_option)

	return row


func _on_special_selected(index: int) -> void:
	GameState.set_daily_special(_species_ids_by_option_index[index])


## --- Terrace upgrades (ticket 13's data/queries; this reuses UpgradeMenu's row pattern) ---

func _refresh_upgrades() -> void:
	var stats := GameState.effective_terrace_stats()
	_stats_label.text = "Upkeep %d/day%s%s" % [
		int(stats["upkeep_per_day"]),
		("  capacity +%d" % int(stats["capacity_delta"])) if int(stats["capacity_delta"]) != 0 else "",
		("  satisfaction +%d" % int(stats["satisfaction_bonus"])) if float(stats.get("satisfaction_bonus", 0)) != 0.0 else "",
	]

	for child in _purchased_list.get_children():
		child.queue_free()
	if GameState.terrace_upgrades.is_empty():
		_purchased_list.add_child(_label("(none yet)"))
	else:
		for upgrade_id in GameState.terrace_upgrades:
			var upgrade := _find_terrace_upgrade(upgrade_id)
			_purchased_list.add_child(_label("- %s: %s" % [upgrade.get("name", upgrade_id), upgrade.get("description", "")]))

	for child in _available_list.get_children():
		child.queue_free()
	var available: Array = GameState.available_terrace_upgrades()
	if available.is_empty():
		_available_list.add_child(_label("No more Terrace upgrades."))
	for upgrade in available:
		_available_list.add_child(_build_upgrade_row(upgrade))


func _build_upgrade_row(upgrade: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var info := Label.new()
	info.text = "%s -- %s (%d cash, %d hearts)" % [
		upgrade["name"], upgrade["description"], int(upgrade["cost_cash"]), int(upgrade["cost_hearts"]),
	]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.custom_minimum_size = Vector2(320, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var buy_btn := Button.new()
	buy_btn.text = "Buy"
	buy_btn.disabled = GameState.cash < int(upgrade["cost_cash"]) or GameState.hearts < int(upgrade["cost_hearts"])
	buy_btn.pressed.connect(_on_buy_pressed.bind(upgrade["id"]))
	row.add_child(buy_btn)

	return row


func _on_buy_pressed(upgrade_id: String) -> void:
	if GameState.purchase_terrace_upgrade(upgrade_id):
		_refresh_upgrades()


func _find_terrace_upgrade(upgrade_id: String) -> Dictionary:
	for upgrade in GameState.terrace.get("upgrades", []):
		if upgrade["id"] == upgrade_id:
			return upgrade
	return {}


func _refresh() -> void:
	_refresh_kitchen()
	_refresh_upgrades()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
