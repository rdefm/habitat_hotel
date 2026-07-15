class_name SimMatching
extends RefCounted

const SimState = preload("res://sim/sim_state.gd")
const SimContent = preload("res://sim/sim_content.gd")
const SimEvents = preload("res://sim/sim_events.gd")

## The single authoritative source of fit (gold/amber/none), satisfaction
## scoring, and seating -- including party-split and partial-seating rules.
## The UI's glow colors must always come from evaluate_fit(), never from
## UI-side logic.

## GOLD: room vacant+clean, capacity fits at least part of the party,
##       room tags cover every species need.
## AMBER: same, but >=1 need missing.
## NONE: room not vacant/clean, unknown room type, or zero seatable capacity.
static func evaluate_fit(room: Dictionary, room_type: Dictionary, species: Dictionary, remaining_party_count: int) -> String:
	if room.get("state", "") != "vacant":
		return "NONE"
	if room_type.is_empty() or species.is_empty():
		return "NONE"
	var capacity := int(room_type.get("capacity", 0))
	var count_to_place := mini(capacity, remaining_party_count)
	if count_to_place < 1:
		return "NONE"
	return "GOLD" if missing_needs(room_type["tags"], species["needs"]).is_empty() else "AMBER"

static func missing_needs(room_tags: Array, species_needs: Array) -> Array:
	var out: Array = []
	for need in species_needs:
		if not room_tags.has(need):
			out.append(need)
	return out

static func likes_met_count(room_tags: Array, species_likes: Array) -> int:
	var count := 0
	for like in species_likes:
		if room_tags.has(like):
			count += 1
	return count

## Flat penalties, applied once each at seating time (Part B: simplest
## option consistent with the pillars -- see DECISIONS.md):
##  - "split" penalty on every room after the first used by a given party.
##  - "partial" penalty on a seating that leaves a remainder behind in the
##    queue, regardless of whether that remainder later gets seated
##    elsewhere (split) or walks (partial seating). A walked remainder
##    itself never gets a stay/satisfaction record, so it incurs no
##    separate penalty -- "no penalty beyond the missed revenue".
static func compute_satisfaction(balance: Dictionary, missing_needs_count: int, likes_met: int, is_first_room_of_party: bool, leaves_remainder: bool) -> float:
	var base := float(balance.get("satisfaction_base", 70))
	var per_like := float(balance.get("satisfaction_per_like_met", 10))
	var amber_penalty := float(balance.get("amber_missing_need_satisfaction_penalty", 25))
	var split_penalty := float(balance.get("party_split_satisfaction_penalty", 10))
	var partial_penalty := float(balance.get("partial_seating_satisfaction_penalty", 8))
	var cap := float(balance.get("satisfaction_cap", 100))

	var value := base + per_like * likes_met - amber_penalty * missing_needs_count
	if not is_first_room_of_party:
		value -= split_penalty
	if leaves_remainder:
		value -= partial_penalty
	return clampf(value, 0.0, cap)

## Executes a {type="seat_guest", party_id, plot_id} command. Mutates
## queue/rooms/stays in place. Validates everything -- never trust the UI.
static func seat_guest(state: SimState, content: SimContent, party_id: int, plot_id: int, events: SimEvents) -> Dictionary:
	var entry := _find_queue_entry(state, party_id)
	if entry == null:
		return {"ok": false, "reason": "no_such_party"}
	var room := _find_room(state, plot_id)
	if room == null:
		return {"ok": false, "reason": "no_such_plot"}

	var room_type: Dictionary = content.rooms.get(room["room_type"], {})
	var species: Dictionary = content.species.get(entry["species_id"], {})
	var fit := evaluate_fit(room, room_type, species, int(entry["party_count"]))
	if fit == "NONE":
		return {"ok": false, "reason": "not_fit"}

	var capacity := int(room_type["capacity"])
	var remaining: int = int(entry["party_count"])
	var count_to_place := mini(capacity, remaining)
	var leaves_remainder := count_to_place < remaining
	var is_first_room: bool = int(entry["rooms_used"]) == 0

	var missing := missing_needs(room_type["tags"], species["needs"])
	var likes := likes_met_count(room_type["tags"], species.get("likes", []))
	var satisfaction := compute_satisfaction(content.balance, missing.size(), likes, is_first_room, leaves_remainder)

	var stay_id := state.next_stay_id
	state.next_stay_id += 1
	var stay := {
		"stay_id": stay_id,
		"plot_id": plot_id,
		"species_id": entry["species_id"],
		"party_count": count_to_place,
		"nights_total": entry["nights_total"],
		"day_seated": state.day,
		"day_checkout": state.day + int(entry["nights_total"]),
		"satisfaction": satisfaction,
		"original_party_id": party_id,
		"needs_missing": missing.size(),
		"likes_met": likes,
	}
	state.stays[str(stay_id)] = stay
	room["state"] = "occupied"
	room["stay_id"] = stay_id

	entry["party_count"] = remaining - count_to_place
	entry["rooms_used"] = int(entry["rooms_used"]) + 1

	events.emit("guest_seated", {
		"stay_id": stay_id,
		"plot_id": plot_id,
		"party_id": party_id,
		"species_id": entry["species_id"],
		"party_count": count_to_place,
		"satisfaction": satisfaction,
		"fit": fit,
		"missing_needs": missing,
		"remainder": entry["party_count"],
	})

	state.day_metrics["seated_parties"] = int(state.day_metrics.get("seated_parties", 0)) + 1
	state.day_metrics["seated_guests"] = int(state.day_metrics.get("seated_guests", 0)) + count_to_place
	if fit == "GOLD":
		state.day_metrics["gold_seats"] = int(state.day_metrics.get("gold_seats", 0)) + 1
	else:
		state.day_metrics["amber_seats"] = int(state.day_metrics.get("amber_seats", 0)) + 1

	if int(entry["party_count"]) <= 0:
		state.queue.erase(entry)

	return {"ok": true, "stay_id": stay_id, "remainder": entry["party_count"]}

static func _find_queue_entry(state: SimState, party_id: int) -> Variant:
	for entry in state.queue:
		if int(entry["party_id"]) == party_id:
			return entry
	return null

static func _find_room(state: SimState, plot_id: int) -> Variant:
	for room in state.rooms:
		if int(room["plot_id"]) == plot_id:
			return room
	return null
