class_name SimQueue
extends RefCounted

const SimState = preload("res://sim/sim_state.gd")
const SimContent = preload("res://sim/sim_content.gd")
const SimEvents = preload("res://sim/sim_events.gd")

## Queue entries, patience decay, and walk-aways. Spawning is driven by
## today_schedule (built by sim_arrivals.gd the night before): each tick,
## any scheduled arrival whose offset has been reached joins the queue.

static func spawn_due_arrivals(state: SimState, content: SimContent, events: SimEvents) -> void:
	match state.phase:
		"morning":
			var popin = state.today_schedule.get("morning_popin")
			if popin != null and not bool(popin.get("spawned", false)) and state.phase_elapsed >= float(popin["offset_sim_seconds"]):
				popin["spawned"] = true
				_append_to_queue(state, content, popin, events)
		"afternoon":
			for party in state.today_schedule.get("afternoon", []):
				if not bool(party.get("spawned", false)) and state.phase_elapsed >= float(party["offset_sim_seconds"]):
					party["spawned"] = true
					_append_to_queue(state, content, party, events)
		"evening":
			var popin = state.today_schedule.get("evening_popin")
			if popin != null and not bool(popin.get("spawned", false)) and state.phase_elapsed >= float(popin["offset_sim_seconds"]):
				popin["spawned"] = true
				_append_to_queue(state, content, popin, events)

static func _append_to_queue(state: SimState, content: SimContent, party: Dictionary, events: SimEvents) -> void:
	var species: Dictionary = content.species.get(party["species_id"], {})
	var base_patience := float(content.balance.get("base_patience_sim_seconds", 35.0))
	var patience_max := base_patience * float(species.get("patience_mult", 1.0))

	var party_id := state.next_party_id
	state.next_party_id += 1
	var entry := {
		"party_id": party_id,
		"species_id": party["species_id"],
		"party_count": party["party_count"],
		"original_party_count": party["party_count"],
		"nights_total": party["nights_total"],
		"patience_remaining": patience_max,
		"patience_max": patience_max,
		"rooms_used": 0,
		"arrival_day": state.day,
	}
	state.queue.append(entry)
	events.emit("guest_arrived", {
		"party_id": party_id,
		"species_id": entry["species_id"],
		"party_count": entry["party_count"],
		"patience_max": patience_max,
	})

## Patience decays in sim-time for every queued party except the one
## currently held by the player (Part A/E; see DECISIONS.md for how the
## "paused while held" + "soft-slow also applies globally" wording was
## resolved -- soft-slow is a single global sim-speed value, so it already
## slows every queued party's decay uniformly).
static func tick_patience(state: SimState, tick_duration: float, events: SimEvents) -> void:
	for entry in state.queue.duplicate():
		entry["patience_remaining"] = float(entry["patience_remaining"]) - tick_duration
		if float(entry["patience_remaining"]) > 0.0:
			continue
		state.queue.erase(entry)
		state.turned_away_log.append({
			"day": state.day,
			"party_id": entry["party_id"],
			"species_id": entry["species_id"],
			"party_count": entry["party_count"],
			"reason": "impatient",
		})
		state.day_metrics["walked_parties"] = int(state.day_metrics.get("walked_parties", 0)) + 1
		state.day_metrics["walked_guests"] = int(state.day_metrics.get("walked_guests", 0)) + int(entry["party_count"])
		events.emit("guest_walked", {
			"party_id": entry["party_id"],
			"species_id": entry["species_id"],
			"party_count": entry["party_count"],
			"reason": "impatient",
		})

## Patience state for the patience-face UI: "content" | "huffy" | "leaving_soon".
static func patience_state(entry: Dictionary, balance: Dictionary) -> String:
	var ratio: float = float(entry["patience_remaining"]) / max(float(entry["patience_max"]), 0.0001)
	var states: Dictionary = balance.get("patience_states", {})
	if ratio > float(states.get("content_above", 0.6)):
		return "content"
	if ratio > float(states.get("huffy_above", 0.25)):
		return "huffy"
	return "leaving_soon"
