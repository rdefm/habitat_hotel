class_name MatchHint
extends RefCounted

## Pure, side-effect-free seating logic (ADR-0001, replacing the deleted
## auto-matcher's policy branching): given a Party and a candidate Room,
## classify() answers "would tapping this Room do anything, and how sure a
## bet is it" -- Sim's seat_party() is the only thing that acts on that
## answer. walk_away_reason() answers the separate question "why did this
## Party never get seated" once its Patience has fully decayed, for the
## same three reasons the old auto-matcher used to produce.
##
## Rooms are addressed by room_type_id + instance_id (see ADR-0004);
## room_stats_by_key/room_stats are always the EFFECTIVE stats (base room
## type merged with that instance's purchased upgrades -- see
## GameState.effective_room_stats), never the raw type catalog, since two
## instances of the same type can carry different upgrades.


## green: every Need is covered. amber: seatable (vacant, clean, affordable,
## non-zero capacity) but missing at least one Need -- a mismatched stay,
## same as the old auto-matcher's "fill_vacancies" admission. none: not a
## valid tap target at all.
##
## Deliberately does NOT compare capacity against the Party's full
## party_size -- an oversized Party is meant to be seatable a chunk at a
## time (see Sim.seat_party()), so a Room smaller than the whole Party still
## shows a hint. Only a Room with zero effective capacity (never true for
## any real data/rooms.json entry today) counts as "too small" for none.
static func classify(party: Dictionary, room: Dictionary, room_stats: Dictionary, price_multipliers: Dictionary, pricing_balance: Dictionary) -> String:
	if room["occupant"] != null or room.get("needs_cleaning", false):
		return "none"
	if int(room_stats["capacity"]) < 1:
		return "none"
	if not _is_affordable(room["room_type_id"], party["budget"], price_multipliers, pricing_balance):
		return "none"
	if _tags_cover_needs(room_stats["tags"], party["needs"]):
		return "green"
	return "amber"


## Why a Party that never got a seat_party() call walked away once its
## Patience hit zero. Reuses the old auto-matcher's strict-match sub-checks
## (capacity >= full party_size, needs fully covered, affordable) so the
## three reasons/reputation effects are unchanged -- with one addition the
## old auto-matcher structurally could never hit: strict_affordable.size() >
## 0 here means an affordable, fully-matching Room sat vacant the whole time
## and the Party simply wasn't seated before Patience ran out. That's a real
## service failure from the guest's point of view (they could have been
## served and weren't), so it's folded into "no_match_available" rather than
## inventing a fourth reason.
static func walk_away_reason(party: Dictionary, hotel_rooms: Array, room_stats_by_key: Dictionary, price_multipliers: Dictionary, pricing_balance: Dictionary) -> String:
	var vacant: Array = hotel_rooms.filter(func(r): return r["occupant"] == null and not r.get("needs_cleaning", false))
	var strict_all: Array = vacant.filter(func(r):
		var rt: Dictionary = room_stats_by_key[room_key(r)]
		return int(rt["capacity"]) >= int(party["party_size"]) and _tags_cover_needs(rt["tags"], party["needs"])
	)
	if strict_all.is_empty():
		return "fully_booked" if vacant.is_empty() else "no_match_available"
	var strict_affordable: Array = strict_all.filter(func(r): return _is_affordable(r["room_type_id"], party["budget"], price_multipliers, pricing_balance))
	return "no_match_available" if strict_affordable.size() > 0 else "too_expensive"


## The key room_stats_by_key is keyed on for a given hotel_rooms entry.
static func room_key(room: Dictionary) -> String:
	return "%s#%d" % [room["room_type_id"], int(room["instance_id"])]


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
