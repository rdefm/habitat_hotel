class_name BuildMenu
extends VBoxContainer

## Build menu: slot grid + room catalog. Pick an empty unlocked slot, then a
## catalog entry to construct there (cash permitting). This is the sim's
## match to "choose what to build for the demand you see."

const HotelPanel = preload("res://ui/hotel_panel.gd")
const DemandFormat = preload("res://ui/demand_format.gd")
const RECENT_DAYS_FOR_DEMAND := 5

var _selected_slot: int = -1
var _hint_label: Label
var _catalog_list: VBoxContainer
var _hotel_panel: HotelPanel


func _ready() -> void:
	custom_minimum_size = Vector2(560, 460)

	add_child(_build_demand_panel())

	var grid_label := Label.new()
	grid_label.text = "Pick an empty, unlocked slot:"
	add_child(grid_label)

	_hotel_panel = HotelPanel.new()
	_hotel_panel.interactive = true
	_hotel_panel.slot_selected.connect(_on_slot_selected)
	add_child(_hotel_panel)

	_hint_label = Label.new()
	add_child(_hint_label)

	var catalog_label := Label.new()
	catalog_label.text = "Room catalog:"
	add_child(catalog_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_catalog_list = VBoxContainer.new()
	_catalog_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_catalog_list)

	_refresh_hint()
	_refresh_catalog()


func _build_demand_panel() -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	panel.add_child(box)

	var forecast_label := Label.new()
	forecast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if GameState.upcoming_arrivals_day > 0:
		forecast_label.text = "Forecast for Day %d: %s" % [
			GameState.upcoming_arrivals_day,
			DemandFormat.summarize_arrivals(GameState.upcoming_arrivals, GameState.species),
		]
	else:
		forecast_label.text = "Forecast for tomorrow isn't ready yet -- check back after tonight's Night phase."
	box.add_child(forecast_label)

	var recent_label := Label.new()
	recent_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	recent_label.text = "Recently turned away (last %d days): %s" % [RECENT_DAYS_FOR_DEMAND, _recent_turned_away_summary()]
	box.add_child(recent_label)

	return panel


func _recent_turned_away_summary() -> String:
	var history: Array = GameState.day_history
	var recent: Array = history.slice(maxi(0, history.size() - RECENT_DAYS_FOR_DEMAND), history.size())
	var totals: Dictionary = {}
	for day_summary in recent:
		var species_counts: Dictionary = day_summary.get("turned_away_species", {})
		for species_id in species_counts.keys():
			totals[species_id] = int(totals.get(species_id, 0)) + int(species_counts[species_id])
	return DemandFormat.summarize_counts(totals, GameState.species)


func _on_slot_selected(slot_index: int) -> void:
	var unlocked := GameState.is_slot_unlocked(slot_index)
	var occupied := not GameState.room_at_slot(slot_index).is_empty()
	if not unlocked or occupied:
		return
	_selected_slot = slot_index
	_refresh_hint()
	_refresh_catalog()


func _refresh_hint() -> void:
	if _selected_slot < 0:
		_hint_label.text = "No slot selected."
	else:
		_hint_label.text = "Selected slot %d. Choose a room to build below." % _selected_slot


func _refresh_catalog() -> void:
	for child in _catalog_list.get_children():
		child.queue_free()

	var room_ids := GameState.rooms.keys()
	room_ids.sort()
	for room_type_id in room_ids:
		var rt: Dictionary = GameState.rooms[room_type_id]
		if not GameState.can_build_room_type(room_type_id):
			continue

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var info := Label.new()
		info.text = "%s (%s)\ncap %d, upkeep %d/day, rate %d/night" % [
			rt["name"], String(", ").join(rt["tags"]), int(rt["capacity"]), int(rt["upkeep_per_day"]), int(rt["base_rate"]),
		]
		info.autowrap_mode = TextServer.AUTOWRAP_WORD
		info.custom_minimum_size = Vector2(300, 0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)

		var build_btn := Button.new()
		build_btn.text = "Build (%d cash)" % int(rt["build_cost"])
		build_btn.disabled = _selected_slot < 0 or GameState.cash < int(rt["build_cost"])
		build_btn.pressed.connect(_on_build_pressed.bind(room_type_id))
		row.add_child(build_btn)

		_catalog_list.add_child(row)


func _on_build_pressed(room_type_id: String) -> void:
	if _selected_slot < 0:
		return
	if GameState.build_room(_selected_slot, room_type_id):
		_selected_slot = -1
		_hotel_panel.refresh()
		_refresh_hint()
		_refresh_catalog()
