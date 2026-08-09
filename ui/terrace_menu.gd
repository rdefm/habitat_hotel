class_name TerraceMenu
extends VBoxContainer

## The Terrace's modal (ticket 05, ADR-0009/0010): Kitchen Station staffing
## -- tap a Staffer card then tap the Kitchen card to (re)assign, the same
## Sim.assign_staffer() call and interruption semantics
## ui/station_panel.gd uses for Reception/Bellhop/Housekeeping (ticket 04),
## via the StafferCard/StationCard widgets moved here off ui/roster_menu.gd
## -- the Daily Special picker, and the Terrace's own Upgrade list (reusing
## UpgradeMenu's purchase-row pattern (tickets 03/13) but addressed by the
## Terrace's single fixed structure instead of room_type_id + instance_id).
##
## The current Daily Special and the breakfast/dinner queues (with
## Patience) now live ambiently in ui/terrace_panel.gd instead -- this modal
## only holds the *interactive* pieces.
##
## Opened by tapping the Terrace structure (main_screen._on_terrace_tapped
## -> open_menu()), which pauses the Clock like every other generic-overlay
## menu -- so this view doesn't need its own tick_advanced refresh wiring.

const StafferCard = preload("res://ui/staffer_card.gd")
const StationCard = preload("res://ui/station_card.gd")

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


## --- Kitchen staffing (moved off ui/roster_menu.gd) ---

func _refresh_kitchen() -> void:
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
	_refresh_kitchen()


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
