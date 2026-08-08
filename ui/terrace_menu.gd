class_name TerraceMenu
extends VBoxContainer

## The Terrace's own view (ticket 14, ADR-0003): the current breakfast queue,
## the current Evening walk-in dinner queue with each Diner's Patience state
## (sim/patience_state.gd, reusing Reception's calm/impatient/huffy tiers --
## see ticket 14's PatienceState generalization), the Daily Special picker,
## and the Terrace's own Upgrade list -- reusing UpgradeMenu's purchase-row
## pattern (tickets 03/13) but addressed by the Terrace's single fixed
## structure instead of room_type_id + instance_id.
##
## Opened as a modal from the menu bar like Prices/Hire/Roster/Reports/
## Reviews, which pauses the Clock (main_screen.open_menu()) -- so unlike
## ReceptionPanel/HotelPanel, this view doesn't need its own tick_advanced
## refresh wiring: nothing in Sim moves while it's open, and _refresh() is
## called again after every mutating action (buying an upgrade, changing the
## Daily Special).
##
## A walkin_queue entry with guest_id != -1 is a room guest's dinner add-on
## (ticket 12) rather than a true Walk-in Diner -- flagged "(Room add-on)"
## here, matching the "+ Dinner" tag hotel_panel.gd already shows on that
## guest's Room card.

const PatienceState = preload("res://sim/patience_state.gd")

const TIER_COLOR := {
	"calm": Color(0.85, 0.95, 1.0),
	"impatient": Color(1.0, 0.75, 0.35),
	"huffy": Color(1.0, 0.45, 0.4),
}

var _breakfast_list: VBoxContainer
var _dinner_list: VBoxContainer
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

	body.add_child(_section_header("Breakfast Queue"))
	_breakfast_list = VBoxContainer.new()
	body.add_child(_breakfast_list)

	body.add_child(_section_header("Walk-in Dinner Queue"))
	_dinner_list = VBoxContainer.new()
	body.add_child(_dinner_list)

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


## --- Breakfast queue (ticket 09) ---

func _refresh_breakfast() -> void:
	for child in _breakfast_list.get_children():
		child.queue_free()
	if Sim.breakfast_queue.is_empty():
		_breakfast_list.add_child(_label("No one waiting for breakfast."))
		return
	for entry in Sim.breakfast_queue:
		var species_id: String = entry["species_id"]
		var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
		var room_name: String = GameState.rooms.get(entry["room_type_id"], {}).get("name", entry["room_type_id"])
		_breakfast_list.add_child(_label("%s x%d -- %s #%d" % [
			species_name, int(entry["party_size"]), room_name, int(entry["instance_id"]),
		]))


## --- Walk-in dinner queue (tickets 10/12), Patience state (ticket 05's PatienceState) ---

func _refresh_dinner() -> void:
	for child in _dinner_list.get_children():
		child.queue_free()
	if Sim.walkin_queue.is_empty():
		_dinner_list.add_child(_label("No one waiting for dinner."))
		return
	var patience_cfg: Dictionary = GameState.balance["dining"]["walkin_patience"]
	for entry in Sim.walkin_queue:
		var species_id: String = entry["species_id"]
		var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
		var tier := PatienceState.tier(float(entry["patience"]), patience_cfg)
		var addon_note := " (Room add-on)" if int(entry.get("guest_id", -1)) != -1 else ""
		var line := _label("%s the %s x%d -- %s%s" % [
			entry["name"], species_name, int(entry["party_size"]), tier.capitalize(), addon_note,
		])
		line.modulate = TIER_COLOR[tier]
		_dinner_list.add_child(line)


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
	_refresh_breakfast()
	_refresh_dinner()
	_refresh_upgrades()


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
