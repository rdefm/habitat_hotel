class_name Matcher
extends RefCounted

## Decides, for one arriving guest party, which vacant room (if any) they
## get seated in under the active policy. Pure decision logic: takes plain
## data in, returns a plain decision dict, mutates nothing. Sim performs the
## actual state changes based on the decision.
##
## Policies:
##  - "strict_match": only seat into a room whose tags are a superset of the
##    guest's needs. Otherwise the guest walks away, even if vacancies exist.
##  - "fill_vacancies": prefer a strict match; if none is vacant, seat into
##    any vacant room big enough (satisfaction penalty applies). Only walks
##    away if there is no vacancy at all for the party size.

static func decide(arrival: Dictionary, hotel_rooms: Array, room_catalog: Dictionary, policy: String) -> Dictionary:
	var vacant: Array = hotel_rooms.filter(func(r): return r["occupant"] == null)

	var strict_fits: Array = vacant.filter(func(r):
		var rt: Dictionary = room_catalog[r["room_type_id"]]
		return int(rt["capacity"]) >= int(arrival["party_size"]) and _tags_cover_needs(rt["tags"], arrival["needs"])
	)
	if strict_fits.size() > 0:
		var chosen := _smallest_capacity(strict_fits, room_catalog)
		return {"action": "matched", "room_slot_index": _index_of_slot(hotel_rooms, chosen["slot"]), "mismatch": false, "reason": "matched_strict"}

	if policy == "fill_vacancies":
		var any_fits: Array = vacant.filter(func(r): return int(room_catalog[r["room_type_id"]]["capacity"]) >= int(arrival["party_size"]))
		if any_fits.size() > 0:
			var chosen2 := _smallest_capacity(any_fits, room_catalog)
			return {"action": "matched", "room_slot_index": _index_of_slot(hotel_rooms, chosen2["slot"]), "mismatch": true, "reason": "matched_mismatch"}
		return {"action": "walk_away", "room_slot_index": -1, "mismatch": false, "reason": "fully_booked"}

	# strict_match policy: no exact-fit vacancy means the guest walks away,
	# regardless of whether mismatched vacancies exist.
	if vacant.size() > 0:
		return {"action": "walk_away", "room_slot_index": -1, "mismatch": false, "reason": "no_match_available"}
	return {"action": "walk_away", "room_slot_index": -1, "mismatch": false, "reason": "fully_booked"}


static func _tags_cover_needs(room_tags: Array, needs: Array) -> bool:
	for need in needs:
		if not room_tags.has(need):
			return false
	return true


static func _smallest_capacity(candidates: Array, room_catalog: Dictionary) -> Dictionary:
	var best: Dictionary = candidates[0]
	var best_capacity: int = int(room_catalog[best["room_type_id"]]["capacity"])
	for r in candidates:
		var cap: int = int(room_catalog[r["room_type_id"]]["capacity"])
		if cap < best_capacity:
			best = r
			best_capacity = cap
	return best


static func _index_of_slot(hotel_rooms: Array, slot: int) -> int:
	for i in range(hotel_rooms.size()):
		if hotel_rooms[i]["slot"] == slot:
			return i
	return -1
