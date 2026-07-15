class_name SimRooms
extends RefCounted

const SimState = preload("res://sim/sim_state.gd")
const SimContent = preload("res://sim/sim_content.gd")
const SimEvents = preload("res://sim/sim_events.gd")

## Room lifecycle: vacant/occupied/dirty/cleaning, checkout processing, and
## the single abstract housekeeping service that cleans dirty rooms one at
## a time, in the order they became dirty.

static func init_starting_hotel(state: SimState, content: SimContent) -> void:
	var hotel: Dictionary = content.balance.get("starting_hotel", {})
	var floors := int(hotel.get("grid_floors", content.balance.get("grid_floors", 3)))
	var per_floor := int(hotel.get("grid_plots_per_floor", content.balance.get("grid_plots_per_floor", 4)))
	var total := floors * per_floor
	var prebuilt: Dictionary = {}
	for entry in hotel.get("prebuilt", []):
		prebuilt[int(entry["plot_id"])] = String(entry["room_type"])

	state.rooms.clear()
	for plot_id in range(total):
		var room_type: String = prebuilt.get(plot_id, "")
		state.rooms.append({
			"plot_id": plot_id,
			"room_type": room_type,
			"state": "vacant" if room_type != "" else "empty",
			"stay_id": -1,
		})

static func room_type_data(content: SimContent, room_type_id: String) -> Dictionary:
	return content.rooms.get(room_type_id, {})

## At Morning start: every occupied room whose stay is complete checks out
## simultaneously, credits cash, and flips dirty.
static func process_checkouts(state: SimState, content: SimContent, events: SimEvents) -> void:
	for room in state.rooms:
		if room["state"] != "occupied":
			continue
		var stay_id: String = str(room["stay_id"])
		if not state.stays.has(stay_id):
			continue
		var stay: Dictionary = state.stays[stay_id]
		if int(stay["day_checkout"]) > state.day:
			continue

		var room_type: Dictionary = room_type_data(content, room["room_type"])
		var nightly_rate := int(room_type.get("nightly_rate", 0))
		var revenue := nightly_rate * int(stay["nights_total"]) * int(stay["party_count"])
		state.cash += revenue

		events.emit("guest_checked_out", {
			"stay_id": stay["stay_id"],
			"plot_id": room["plot_id"],
			"species_id": stay["species_id"],
			"party_count": stay["party_count"],
			"satisfaction": stay["satisfaction"],
			"revenue": revenue,
		})

		room["state"] = "dirty"
		room["stay_id"] = -1
		state.stays.erase(stay_id)
		state.housekeeping_order.append(room["plot_id"])

		state.day_metrics["checkouts"] = int(state.day_metrics.get("checkouts", 0)) + 1
		var sats: Array = state.day_metrics.get("checkout_satisfactions", [])
		sats.append(stay["satisfaction"])
		state.day_metrics["checkout_satisfactions"] = sats

	start_next_clean_if_idle(state, events)

static func start_next_clean_if_idle(state: SimState, events: SimEvents) -> void:
	if state.cleaning_plot_id != -1:
		return
	if state.housekeeping_order.is_empty():
		return
	var plot_id: int = state.housekeeping_order.pop_front()
	state.cleaning_plot_id = plot_id
	state.cleaning_progress = 0.0
	events.emit("clean_started", {"plot_id": plot_id})

static func tick_housekeeping(state: SimState, content: SimContent, tick_duration: float, events: SimEvents) -> void:
	if state.cleaning_plot_id == -1:
		return
	var room := _room_at(state, state.cleaning_plot_id)
	if room == null:
		state.cleaning_plot_id = -1
		return
	room["state"] = "cleaning"
	state.cleaning_progress += tick_duration
	var duration := float(content.balance.get("clean_duration_sim_seconds", 14.0))
	if state.cleaning_progress < duration:
		return

	room["state"] = "vacant"
	var finished_plot: int = state.cleaning_plot_id
	state.cleaning_plot_id = -1
	state.cleaning_progress = 0.0
	state.day_metrics["rooms_cleaned"] = int(state.day_metrics.get("rooms_cleaned", 0)) + 1
	events.emit("clean_finished", {"plot_id": finished_plot})
	start_next_clean_if_idle(state, events)

static func build_room(state: SimState, content: SimContent, plot_id: int, room_type_id: String, events: SimEvents) -> Dictionary:
	var room := _room_at(state, plot_id)
	if room == null:
		return {"ok": false, "reason": "no_such_plot"}
	if room["state"] != "empty":
		return {"ok": false, "reason": "plot_occupied"}
	if not content.rooms.has(room_type_id):
		return {"ok": false, "reason": "no_such_room_type"}
	var room_type: Dictionary = content.rooms[room_type_id]
	var max_tier := int(content.balance.get("max_room_tier", 99))
	if int(room_type["tier"]) > max_tier:
		return {"ok": false, "reason": "room_type_locked"}
	var cost := int(room_type["build_cost"])
	if state.cash < cost:
		return {"ok": false, "reason": "insufficient_cash"}

	state.cash -= cost
	room["room_type"] = room_type_id
	room["state"] = "vacant"
	events.emit("room_built", {"plot_id": plot_id, "room_type": room_type_id})
	return {"ok": true}

static func _room_at(state: SimState, plot_id: int) -> Variant:
	for room in state.rooms:
		if int(room["plot_id"]) == plot_id:
			return room
	return null
