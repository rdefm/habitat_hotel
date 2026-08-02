extends GutTest

## Characterizes sim/matcher.gd's decide() under both current policies
## (strict_match / fill_vacancies), addressed by room_type_id + instance_id
## (see .scratch/direct-manipulation-core-loop/issues/02-floor-data-model.md)
## before this policy-branching logic is deleted entirely in favor of manual
## seating -- see ADR-0001 and
## .scratch/direct-manipulation-core-loop/issues/04-manual-seating-core.md.
##
## Matcher.decide() is a pure function, so these tests craft minimal literal
## inputs rather than depending on GameState's loaded data/*.json content.

const Matcher = preload("res://sim/matcher.gd")

const PRICING_BALANCE := {
	"tolerance": {
		"mid": {"max_multiplier": 1.3},
	},
}


func _arrival(needs: Array, party_size: int, budget: String = "mid") -> Dictionary:
	return {"species_id": "test_species", "needs": needs, "party_size": party_size, "budget": budget}


func _room(instance_id: int, occupant: Variant = null, needs_cleaning: bool = false) -> Dictionary:
	return {"room_type_id": "test_room", "instance_id": instance_id, "occupant": occupant, "needs_cleaning": needs_cleaning}


func test_strict_match_admits_a_guest_whose_needs_are_fully_covered() -> void:
	var arrival := _arrival(["cold", "water"], 2)
	var room := _room(0)
	var hotel_rooms := [room]
	var room_stats := {Matcher.room_key(room): {"capacity": 2, "tags": ["cold", "water"]}}
	var price_multipliers := {"test_room": 1.0}

	var decision := Matcher.decide(arrival, hotel_rooms, room_stats, "strict_match", price_multipliers, PRICING_BALANCE)

	assert_eq(decision["action"], "matched")
	assert_eq(decision["reason"], "matched_strict")
	assert_eq(decision["room_type_id"], "test_room")
	assert_eq(decision["instance_id"], 0)
	assert_false(decision["mismatch"])


func test_fill_vacancies_admits_the_same_strict_match_a_guest_would_get_under_strict_match() -> void:
	var arrival := _arrival(["cold", "water"], 2)
	var room := _room(0)
	var hotel_rooms := [room]
	var room_stats := {Matcher.room_key(room): {"capacity": 2, "tags": ["cold", "water"]}}
	var price_multipliers := {"test_room": 1.0}

	var decision := Matcher.decide(arrival, hotel_rooms, room_stats, "fill_vacancies", price_multipliers, PRICING_BALANCE)

	assert_eq(decision["action"], "matched")
	assert_eq(decision["reason"], "matched_strict")
	assert_false(decision["mismatch"])


func test_strict_match_turns_away_a_guest_when_only_a_mismatched_vacancy_exists() -> void:
	var arrival := _arrival(["cold", "water"], 2)
	var room := _room(0)
	var hotel_rooms := [room]
	var room_stats := {Matcher.room_key(room): {"capacity": 2, "tags": ["warm", "water"]}} # missing "cold"
	var price_multipliers := {"test_room": 1.0}

	var decision := Matcher.decide(arrival, hotel_rooms, room_stats, "strict_match", price_multipliers, PRICING_BALANCE)

	assert_eq(decision["action"], "walk_away")
	assert_eq(decision["reason"], "no_match_available")
	assert_eq(decision["instance_id"], -1)


func test_fill_vacancies_admits_the_same_guest_into_the_mismatched_vacancy_instead_of_turning_away() -> void:
	var arrival := _arrival(["cold", "water"], 2)
	var room := _room(0)
	var hotel_rooms := [room]
	var room_stats := {Matcher.room_key(room): {"capacity": 2, "tags": ["warm", "water"]}} # missing "cold"
	var price_multipliers := {"test_room": 1.0}

	var decision := Matcher.decide(arrival, hotel_rooms, room_stats, "fill_vacancies", price_multipliers, PRICING_BALANCE)

	assert_eq(decision["action"], "matched")
	assert_eq(decision["reason"], "matched_mismatch")
	assert_eq(decision["room_type_id"], "test_room")
	assert_eq(decision["instance_id"], 0)
	assert_true(decision["mismatch"])


func test_both_policies_turn_a_guest_away_when_every_room_is_occupied() -> void:
	var arrival := _arrival(["cold", "water"], 2)
	var room := _room(0, 42) # occupied
	var hotel_rooms := [room]
	var room_stats := {Matcher.room_key(room): {"capacity": 2, "tags": ["cold", "water"]}}
	var price_multipliers := {"test_room": 1.0}

	var strict_decision := Matcher.decide(arrival, hotel_rooms, room_stats, "strict_match", price_multipliers, PRICING_BALANCE)
	var fill_decision := Matcher.decide(arrival, hotel_rooms, room_stats, "fill_vacancies", price_multipliers, PRICING_BALANCE)

	assert_eq(strict_decision["reason"], "fully_booked")
	assert_eq(fill_decision["reason"], "fully_booked")


func test_fill_vacancies_turns_a_guest_away_as_too_expensive_when_the_only_vacancy_is_over_budget_tolerance() -> void:
	var arrival := _arrival(["cold", "water"], 2)
	var room := _room(0)
	var hotel_rooms := [room]
	var room_stats := {Matcher.room_key(room): {"capacity": 2, "tags": ["cold", "water"]}}
	var price_multipliers := {"test_room": 5.0} # far above "mid" tolerance's max_multiplier of 1.3

	var decision := Matcher.decide(arrival, hotel_rooms, room_stats, "fill_vacancies", price_multipliers, PRICING_BALANCE)

	assert_eq(decision["action"], "walk_away")
	assert_eq(decision["reason"], "too_expensive")
