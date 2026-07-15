class_name SimEconomyStub
extends RefCounted

const SimState = preload("res://sim/sim_state.gd")

## Placeholder economy: day-metrics accumulation and the Night-phase day
## summary. Real economy (Hearts/reputation/reviews) arrives in M3 -- this
## file only has to produce the numbers the M1 summary screen needs, and
## keep them right so M3 can consume them later.

static func reset_day_metrics(state: SimState, day: int) -> void:
	state.day_metrics = {
		"day": day,
		"cash_start": state.cash,
		"seated_parties": 0,
		"seated_guests": 0,
		"gold_seats": 0,
		"amber_seats": 0,
		"walked_parties": 0,
		"walked_guests": 0,
		"checkouts": 0,
		"checkout_satisfactions": [],
		"rooms_cleaned": 0,
	}

static func build_day_summary(state: SimState) -> Dictionary:
	var m: Dictionary = state.day_metrics
	var sats: Array = m.get("checkout_satisfactions", [])
	var mean_sat := 0.0
	if not sats.is_empty():
		var total := 0.0
		for s in sats:
			total += float(s)
		mean_sat = total / sats.size()

	var occupied := 0
	for room in state.rooms:
		if room["state"] == "occupied":
			occupied += 1
	var occupancy := (float(occupied) / float(state.rooms.size())) if not state.rooms.is_empty() else 0.0

	return {
		"day": m.get("day", state.day),
		"cash_start": m.get("cash_start", state.cash),
		"cash_end": state.cash,
		"cash_delta": state.cash - int(m.get("cash_start", state.cash)),
		"seated_parties": m.get("seated_parties", 0),
		"seated_guests": m.get("seated_guests", 0),
		"gold_seats": m.get("gold_seats", 0),
		"amber_seats": m.get("amber_seats", 0),
		"walked_parties": m.get("walked_parties", 0),
		"walked_guests": m.get("walked_guests", 0),
		"checkouts": m.get("checkouts", 0),
		"mean_checkout_satisfaction": mean_sat,
		"occupancy_rate": occupancy,
		"rooms_cleaned": m.get("rooms_cleaned", 0),
	}
