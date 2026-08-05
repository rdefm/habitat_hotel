extends GutTest

## Characterizes sim/match_hint.gd's two pure functions -- classify() (the
## green/amber/none seating hint for a selected Party against a candidate
## Room) and walk_away_reason() (why an expired Party never got seated) --
## addressed by room_type_id + instance_id (see ADR-0004), replacing the
## deleted auto-matcher's policy branching in favor of manual seating (see
## ADR-0001 and
## .scratch/direct-manipulation-core-loop/issues/04-manual-seating-core.md).
##
## Both are pure functions, so these tests craft minimal literal inputs
## rather than depending on GameState's loaded data/*.json content.

const MatchHint = preload("res://sim/match_hint.gd")

const PRICING_BALANCE := {
	"tolerance": {
		"mid": {"max_multiplier": 1.3},
	},
}


func _party(needs: Array, party_size: int, budget: String = "mid") -> Dictionary:
	return {"species_id": "test_species", "needs": needs, "party_size": party_size, "budget": budget}


func _room(instance_id: int, occupant: Variant = null, needs_cleaning: bool = false) -> Dictionary:
	return {"room_type_id": "test_room", "instance_id": instance_id, "occupant": occupant, "needs_cleaning": needs_cleaning}


## --- classify() ---

func test_classify_is_green_when_every_need_is_covered() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0)
	var room_stats := {"capacity": 2, "tags": ["cold", "water"]}

	var hint := MatchHint.classify(party, room, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(hint, "green")


func test_classify_is_amber_when_missing_one_need_but_otherwise_seatable() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0)
	var room_stats := {"capacity": 2, "tags": ["warm", "water"]} # missing "cold"

	var hint := MatchHint.classify(party, room, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(hint, "amber")


func test_classify_is_amber_when_covering_none_of_the_needs_but_otherwise_seatable() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0)
	var room_stats := {"capacity": 2, "tags": ["spacious"]}

	var hint := MatchHint.classify(party, room, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(hint, "amber", "any vacant/clean/affordable room is a mismatched-but-seatable stay, not a non-target")


func test_classify_is_none_when_the_room_is_occupied() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0, 42)
	var room_stats := {"capacity": 2, "tags": ["cold", "water"]}

	var hint := MatchHint.classify(party, room, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(hint, "none")


func test_classify_is_none_when_the_room_needs_cleaning() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0, null, true)
	var room_stats := {"capacity": 2, "tags": ["cold", "water"]}

	var hint := MatchHint.classify(party, room, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(hint, "none")


func test_classify_is_none_when_unaffordable_for_the_partys_budget_tier() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0)
	var room_stats := {"capacity": 2, "tags": ["cold", "water"]}

	var hint := MatchHint.classify(party, room, room_stats, {"test_room": 5.0}, PRICING_BALANCE) # far above "mid" tolerance's 1.3

	assert_eq(hint, "none")


func test_classify_is_none_when_the_room_has_zero_effective_capacity() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0)
	var room_stats := {"capacity": 0, "tags": ["cold", "water"]}

	var hint := MatchHint.classify(party, room, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(hint, "none")


func test_classify_ignores_capacity_smaller_than_the_full_party_size() -> void:
	# Splitting a Party across multiple Rooms is a feature, not a "too small"
	# rejection -- a Room that can only take part of the Party still hints.
	var party := _party(["cold", "water"], 5)
	var room := _room(0)
	var room_stats := {"capacity": 2, "tags": ["cold", "water"]}

	var hint := MatchHint.classify(party, room, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(hint, "green")


## --- missing_needs() ---

func test_missing_needs_lists_only_needs_the_room_doesnt_cover() -> void:
	var party := _party(["cold", "water", "quiet"], 2)
	var room_stats := {"tags": ["warm", "water"]} # covers water, not cold/quiet

	var missing := MatchHint.missing_needs(party, room_stats)

	assert_eq(missing, ["cold", "quiet"])


func test_missing_needs_is_empty_when_every_need_is_covered() -> void:
	var party := _party(["cold", "water"], 2)
	var room_stats := {"tags": ["cold", "water", "spacious"]}

	var missing := MatchHint.missing_needs(party, room_stats)

	assert_eq(missing, [])


## --- walk_away_reason() ---

func test_walk_away_reason_is_no_match_available_when_no_room_type_could_ever_fit() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0)
	var hotel_rooms := [room]
	var room_stats := {MatchHint.room_key(room): {"capacity": 2, "tags": ["warm", "water"]}} # missing "cold"

	var reason := MatchHint.walk_away_reason(party, hotel_rooms, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(reason, "no_match_available")


func test_walk_away_reason_is_fully_booked_when_every_room_is_occupied() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0, 42) # occupied
	var hotel_rooms := [room]
	var room_stats := {MatchHint.room_key(room): {"capacity": 2, "tags": ["cold", "water"]}}

	var reason := MatchHint.walk_away_reason(party, hotel_rooms, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(reason, "fully_booked")


func test_walk_away_reason_is_too_expensive_when_the_only_full_match_is_over_budget_tolerance() -> void:
	var party := _party(["cold", "water"], 2)
	var room := _room(0)
	var hotel_rooms := [room]
	var room_stats := {MatchHint.room_key(room): {"capacity": 2, "tags": ["cold", "water"]}}

	var reason := MatchHint.walk_away_reason(party, hotel_rooms, room_stats, {"test_room": 5.0}, PRICING_BALANCE) # far above tolerance

	assert_eq(reason, "too_expensive")


func test_walk_away_reason_is_no_match_available_when_an_affordable_full_match_sat_unused() -> void:
	# The party's own Patience simply ran out before anyone tapped a room
	# that was, the whole time, an affordable and complete match -- from the
	# guest's point of view that's still a real missed service, same as the
	# old auto-matcher's "no eligible room type" case.
	var party := _party(["cold", "water"], 2)
	var room := _room(0)
	var hotel_rooms := [room]
	var room_stats := {MatchHint.room_key(room): {"capacity": 2, "tags": ["cold", "water"]}}

	var reason := MatchHint.walk_away_reason(party, hotel_rooms, room_stats, {"test_room": 1.0}, PRICING_BALANCE)

	assert_eq(reason, "no_match_available")
