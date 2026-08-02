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
## Rooms are addressed by room_type_id + instance_id (see ADR-0004) rather
## than a flat slot index. room_stats_by_key maps each hotel_rooms entry's
## room_key() to its EFFECTIVE stats (base room type merged with that
## specific instance's purchased upgrades -- see GameState.effective_room_stats)
## rather than the raw type catalog, since two rooms of the same type can
## carry different upgrades.
##
## A room only counts as a candidate if its current price (base_rate *
## price_multiplier) is within the guest's budget tier's tolerance -- see
## data/balance.json's "pricing.tolerance". A guest who'd otherwise fit but
## can't afford any candidate room walks away with reason "too_expensive"
## rather than "fully_booked"/"no_match_available".

static func decide(arrival: Dictionary, hotel_rooms: Array, room_stats_by_key: Dictionary, policy: String, price_multipliers: Dictionary, pricing_balance: Dictionary) -> Dictionary:
	var vacant: Array = hotel_rooms.filter(func(r): return r["occupant"] == null and not r.get("needs_cleaning", false))

	var strict_all: Array = vacant.filter(func(r):
		var rt: Dictionary = room_stats_by_key[room_key(r)]
		return int(rt["capacity"]) >= int(arrival["party_size"]) and _tags_cover_needs(rt["tags"], arrival["needs"])
	)
	var strict_affordable: Array = strict_all.filter(func(r): return _is_affordable(r["room_type_id"], arrival["budget"], price_multipliers, pricing_balance))
	if strict_affordable.size() > 0:
		var chosen := _smallest_capacity(strict_affordable, room_stats_by_key)
		return _matched(chosen, false, "matched_strict")

	if policy == "fill_vacancies":
		var any_all: Array = vacant.filter(func(r): return int(room_stats_by_key[room_key(r)]["capacity"]) >= int(arrival["party_size"]))
		var any_affordable: Array = any_all.filter(func(r): return _is_affordable(r["room_type_id"], arrival["budget"], price_multipliers, pricing_balance))
		if any_affordable.size() > 0:
			var chosen2 := _smallest_capacity(any_affordable, room_stats_by_key)
			return _matched(chosen2, true, "matched_mismatch")
		if any_all.size() > 0:
			return _walk_away("too_expensive")
		return _walk_away("fully_booked")

	# strict_match policy: a mismatched room is never an option.
	if strict_all.size() > 0:
		return _walk_away("too_expensive")
	if vacant.size() > 0:
		return _walk_away("no_match_available")
	return _walk_away("fully_booked")


## The key room_stats_by_key is keyed on for a given hotel_rooms entry.
static func room_key(room: Dictionary) -> String:
	return "%s#%d" % [room["room_type_id"], int(room["instance_id"])]


static func _matched(room: Dictionary, mismatch: bool, reason: String) -> Dictionary:
	return {"action": "matched", "room_type_id": room["room_type_id"], "instance_id": int(room["instance_id"]), "mismatch": mismatch, "reason": reason}


static func _walk_away(reason: String) -> Dictionary:
	return {"action": "walk_away", "room_type_id": "", "instance_id": -1, "mismatch": false, "reason": reason}


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


static func _smallest_capacity(candidates: Array, room_stats_by_key: Dictionary) -> Dictionary:
	var best: Dictionary = candidates[0]
	var best_capacity: int = int(room_stats_by_key[room_key(best)]["capacity"])
	for r in candidates:
		var cap: int = int(room_stats_by_key[room_key(r)]["capacity"])
		if cap < best_capacity:
			best = r
			best_capacity = cap
	return best
