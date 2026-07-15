class_name Matcher
extends RefCounted

## Decides, for one arriving guest party, which vacant room (if any) they
## get seated in under the active policy and current prices. Pure decision
## logic: takes plain data in, returns a plain decision dict, mutates
## nothing. Sim performs the actual state changes based on the decision.
##
## Policies:
##  - "strict_match": only seat into a room whose tags are a superset of the
##    guest's needs. Otherwise the guest walks away, even if vacancies exist.
##  - "fill_vacancies": prefer a strict match; if none is vacant/affordable,
##    seat into any vacant room big enough (satisfaction penalty applies).
##    Only walks away if there is no affordable vacancy at all.
##
## room_stats_by_slot maps each hotel_rooms slot index to its EFFECTIVE
## stats (base room type merged with that specific instance's purchased
## upgrades -- see GameState.effective_room_stats) rather than the raw type
## catalog, since two rooms of the same type can carry different upgrades.
##
## A room only counts as a candidate if its current price (base_rate *
## price_multiplier) is within the guest's budget tier's tolerance -- see
## data/balance.json's "pricing.tolerance". A guest who'd otherwise fit but
## can't afford any candidate room walks away with reason "too_expensive"
## rather than "fully_booked"/"no_match_available".

static func decide(arrival: Dictionary, hotel_rooms: Array, room_stats_by_slot: Dictionary, policy: String, price_multipliers: Dictionary, pricing_balance: Dictionary) -> Dictionary:
	var vacant: Array = hotel_rooms.filter(func(r): return r["occupant"] == null)

	var strict_all: Array = vacant.filter(func(r):
		var rt: Dictionary = room_stats_by_slot[r["slot"]]
		return int(rt["capacity"]) >= int(arrival["party_size"]) and _tags_cover_needs(rt["tags"], arrival["needs"])
	)
	var strict_affordable: Array = strict_all.filter(func(r): return _is_affordable(r["room_type_id"], arrival["budget"], price_multipliers, pricing_balance))
	if strict_affordable.size() > 0:
		var chosen := _smallest_capacity(strict_affordable, room_stats_by_slot)
		return {"action": "matched", "room_slot_index": _index_of_slot(hotel_rooms, chosen["slot"]), "mismatch": false, "reason": "matched_strict"}

	if policy == "fill_vacancies":
		var any_all: Array = vacant.filter(func(r): return int(room_stats_by_slot[r["slot"]]["capacity"]) >= int(arrival["party_size"]))
		var any_affordable: Array = any_all.filter(func(r): return _is_affordable(r["room_type_id"], arrival["budget"], price_multipliers, pricing_balance))
		if any_affordable.size() > 0:
			var chosen2 := _smallest_capacity(any_affordable, room_stats_by_slot)
			return {"action": "matched", "room_slot_index": _index_of_slot(hotel_rooms, chosen2["slot"]), "mismatch": true, "reason": "matched_mismatch"}
		if any_all.size() > 0:
			return {"action": "walk_away", "room_slot_index": -1, "mismatch": false, "reason": "too_expensive"}
		return {"action": "walk_away", "room_slot_index": -1, "mismatch": false, "reason": "fully_booked"}

	# strict_match policy: a mismatched room is never an option.
	if strict_all.size() > 0:
		return {"action": "walk_away", "room_slot_index": -1, "mismatch": false, "reason": "too_expensive"}
	if vacant.size() > 0:
		return {"action": "walk_away", "room_slot_index": -1, "mismatch": false, "reason": "no_match_available"}
	return {"action": "walk_away", "room_slot_index": -1, "mismatch": false, "reason": "fully_booked"}


static func _is_affordable(room_type_id: String, budget: String, price_multipliers: Dictionary, pricing_balance: Dictionary) -> bool:
	if pricing_balance.is_empty():
		return true
	var current: float = float(price_multipliers.get(room_type_id, 1.0))
	var tolerance: Dictionary = pricing_balance.get("tolerance", {}).get(budget, {})
	var max_multiplier: float = float(tolerance.get("max_multiplier", 999.0))
	return current <= max_multiplier


static func _tags_cover_needs(room_tags: Array, needs: Array) -> bool:
	for need in needs:
		if not room_tags.has(need):
			return false
	return true


static func _smallest_capacity(candidates: Array, room_stats_by_slot: Dictionary) -> Dictionary:
	var best: Dictionary = candidates[0]
	var best_capacity: int = int(room_stats_by_slot[best["slot"]]["capacity"])
	for r in candidates:
		var cap: int = int(room_stats_by_slot[r["slot"]]["capacity"])
		if cap < best_capacity:
			best = r
			best_capacity = cap
	return best


static func _index_of_slot(hotel_rooms: Array, slot: int) -> int:
	for i in range(hotel_rooms.size()):
		if hotel_rooms[i]["slot"] == slot:
			return i
	return -1
