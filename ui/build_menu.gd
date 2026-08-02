class_name BuildMenu
extends VBoxContainer

## Build menu for one pre-chosen Floor's Room type. Opened by tapping that
## Floor's Build Slot on the main grid, which sets room_type_id before adding
## this to the scene -- this menu never shows a catalog of other Room types,
## since a Build Slot only ever builds another instance of its own Floor's
## type (ADR-0004). This is the sim's match to "choose to build for the
## demand you see."

const DemandFormat = preload("res://ui/demand_format.gd")
const RECENT_DAYS_FOR_DEMAND := 5

## Set by the caller before this node enters the tree.
var room_type_id: String = ""

signal build_completed


func _ready() -> void:
	custom_minimum_size = Vector2(560, 460)

	add_child(_build_demand_panel())
	add_child(_build_catalog_row())


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


func _build_catalog_row() -> Control:
	var rt: Dictionary = GameState.rooms[room_type_id]

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
	build_btn.disabled = GameState.cash < int(rt["build_cost"]) or not GameState.can_build_more(room_type_id)
	build_btn.pressed.connect(_on_build_pressed)
	row.add_child(build_btn)

	return row


func _on_build_pressed() -> void:
	if GameState.build_room(room_type_id):
		build_completed.emit()
