class_name BuildConfirmMenu
extends VBoxContainer

## Bespoke small popup (ADR-0011, ticket 03) shown when tapping a Build Slot:
## confirms constructing another instance of that Floor's Room type. Shows
## cost/capacity/upkeep plus the same forecast / recently-turned-away context
## the old generic-overlay BuildMenu showed, so "what do I build here" is
## still answerable from the popup. A Build Slot only ever builds another
## instance of its own Floor's type (ADR-0004), so there's no catalog of
## other Room types to choose from. Opened via main_screen's PopupHost, same
## as SeatConfirmMenu/StayInfoMenu.

const DemandFormat = preload("res://ui/demand_format.gd")
const RECENT_DAYS_FOR_DEMAND := 5

## Set by the caller before this node enters the tree.
var room_type_id: String = ""

## resolved(built): true if the player confirmed and GameState.build_room()
## succeeded, false if they cancelled -- or confirmed but it somehow failed,
## a safety net since the Build button is disabled whenever it would.
signal resolved(built: bool)


func _ready() -> void:
	custom_minimum_size = Vector2(420, 320)

	var rt: Dictionary = GameState.rooms[room_type_id]

	var info := Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.text = "Build %s (%s)?\ncap %d, upkeep %d/day, rate %d/night" % [
		rt["name"], String(", ").join(rt["tags"]), int(rt["capacity"]), int(rt["upkeep_per_day"]), int(rt["base_rate"]),
	]
	add_child(info)

	var forecast_label := Label.new()
	forecast_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	if GameState.upcoming_arrivals_day > 0:
		forecast_label.text = "Forecast for Day %d: %s" % [
			GameState.upcoming_arrivals_day,
			DemandFormat.summarize_arrivals(GameState.upcoming_arrivals, GameState.species),
		]
	else:
		forecast_label.text = "Forecast for tomorrow isn't ready yet -- check back after tonight's Night phase."
	add_child(forecast_label)

	var recent_label := Label.new()
	recent_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	recent_label.text = "Recently turned away (last %d days): %s" % [RECENT_DAYS_FOR_DEMAND, _recent_turned_away_summary()]
	add_child(recent_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var build_btn := Button.new()
	build_btn.text = "Build (%d cash)" % int(rt["build_cost"])
	build_btn.disabled = GameState.cash < int(rt["build_cost"]) or not GameState.can_build_more(room_type_id)
	build_btn.pressed.connect(_on_build_pressed)
	row.add_child(build_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	row.add_child(cancel_btn)


func _recent_turned_away_summary() -> String:
	var history: Array = GameState.day_history
	var recent: Array = history.slice(maxi(0, history.size() - RECENT_DAYS_FOR_DEMAND), history.size())
	var totals: Dictionary = {}
	for day_summary in recent:
		var species_counts: Dictionary = day_summary.get("turned_away_species", {})
		for species_id in species_counts.keys():
			totals[species_id] = int(totals.get(species_id, 0)) + int(species_counts[species_id])
	return DemandFormat.summarize_counts(totals, GameState.species)


func _on_build_pressed() -> void:
	resolved.emit(GameState.build_room(room_type_id))


func _on_cancel_pressed() -> void:
	resolved.emit(false)
