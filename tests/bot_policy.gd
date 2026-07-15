class_name BotPolicy
extends RefCounted

const SimGame = preload("res://sim/sim_game.gd")
const SimState = preload("res://sim/sim_state.gd")
const SimContent = preload("res://sim/sim_content.gd")
const SimMatching = preload("res://sim/sim_matching.gd")

## "Attentive bot" policy for Part F tests 6/7/8: seats the best available
## option for every queued party the moment it exists. Prefers GOLD over
## AMBER; keeps seating a party into further rooms until it is fully
## seated or no room fits any remainder.

static func act(sim: SimGame) -> void:
	var state: SimState = sim.get_state()
	var party_ids: Array = []
	for entry in state.queue:
		party_ids.append(int(entry["party_id"]))
	for party_id in party_ids:
		_try_seat_party(sim, party_id)

static func _try_seat_party(sim: SimGame, party_id: int) -> void:
	var state: SimState = sim.get_state()
	var content: SimContent = sim.get_content()
	var guard := 0
	while guard < 10:
		guard += 1
		var entry = _find_entry(state, party_id)
		if entry == null:
			return
		var best_plot := _find_best_room(state, content, entry)
		if best_plot == -1:
			return
		var result := sim.submit({"type": "seat_guest", "party_id": party_id, "plot_id": best_plot})
		if not bool(result.get("ok", false)):
			return
		if int(result.get("remainder", 0)) <= 0:
			return

static func _find_entry(state: SimState, party_id: int):
	for entry in state.queue:
		if int(entry["party_id"]) == party_id:
			return entry
	return null

static func _find_best_room(state: SimState, content: SimContent, entry: Dictionary) -> int:
	var species: Dictionary = content.species.get(entry["species_id"], {})
	var gold_plot := -1
	var amber_plot := -1
	for room in state.rooms:
		var room_type: Dictionary = content.rooms.get(room["room_type"], {})
		var fit := SimMatching.evaluate_fit(room, room_type, species, int(entry["party_count"]))
		if fit == "GOLD" and gold_plot == -1:
			gold_plot = int(room["plot_id"])
		elif fit == "AMBER" and amber_plot == -1:
			amber_plot = int(room["plot_id"])
	return gold_plot if gold_plot != -1 else amber_plot
