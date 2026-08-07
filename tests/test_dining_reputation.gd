extends "res://tests/helpers/sim_test_base.gd"

## Characterizes ticket 11 (ADR-0003's fix): a served Walk-in Diner's meal is
## scored through Satisfaction.compute_dining() -- the same Satisfaction
## module Checkouts use, fed through the very same review_for()/
## hearts_for()/reputation_delta_for_review() -- and that score drives
## Hearts/Reputation exactly like a good/bad stay does, not the reference
## prototype's cash-only path (see habitat-hotel-prototype-4.html's
## WALKIN_REVENUE_PER_DINER, "cash only, no Hearts (§9)"). An unserved
## Walk-in Diner who walks away from Patience expiry costs Reputation the
## same way a lost Room-booking Party's walk-away does. See
## .scratch/direct-manipulation-core-loop/issues/11-dining-reputation-hearts.md.
##
## The room-guest dinner add-on (ticket 12) doesn't exist yet. Once it lands
## feeding entries into this same walkin_queue/_tick_dinner() pipeline (per
## ticket 12's own acceptance criteria), it gets this file's Reputation/
## Hearts handling for free through Sim._serve_walkin_diner()/
## _decay_walkin_patience() -- no dining-specific code of its own needed.
##
## Starting hotel/roster as in test_walkin_dinner.gd: Marlon (kitchen skill
## 3) is the only starting Staffer who clears stations.kitchen.dinner_min_skill (3).
## Clock phase boundaries (autoload/clock.gd): EVENING starts at tick 161,
## NIGHT at tick 221.

const EVENING_START_TICK := 161
const MARLON_DINNER_TICKS := 22 # balance.json's dinner_ticks_by_skill, skill 3
const MARLON_KITCHEN_SKILL := 3


func _push_walkin(id: int, patience: float, species_id: String = "test_species") -> void:
	Sim.walkin_queue.append({
		"id": id,
		"name": "Test Diner %d" % id,
		"species_id": species_id,
		"party_size": 1,
		"patience": patience,
	})


## --- Satisfaction.compute_dining() is a pure function of Daily Special match + Kitchen skill ---

func test_dining_score_rises_with_a_daily_special_match() -> void:
	var balance: Dictionary = GameState.balance
	var without_match := Satisfaction.compute_dining(false, MARLON_KITCHEN_SKILL, balance)
	var with_match := Satisfaction.compute_dining(true, MARLON_KITCHEN_SKILL, balance)
	assert_gt(with_match, without_match, "matching the Daily Special should raise the dining score")


func test_dining_score_rises_with_kitchen_skill() -> void:
	var balance: Dictionary = GameState.balance
	var low_skill := Satisfaction.compute_dining(false, 1, balance)
	var high_skill := Satisfaction.compute_dining(false, 5, balance)
	assert_gt(high_skill, low_skill, "a more skilled cook should raise the dining score")


## --- A served Walk-in Diner feeds Hearts/Reputation through Satisfaction, same as a Checkout ---

func test_served_walkin_diner_matching_daily_special_produces_hearts_and_a_positive_reputation_delta() -> void:
	Sim.assign_staffer("marlon", "kitchen")
	Clock.force_advance_ticks(EVENING_START_TICK)
	Sim.walkin_queue.clear()
	GameState.set_daily_special("pigeon") # a real Species id -- set_daily_special() rejects unknown ones
	_push_walkin(1, 999.0, "pigeon")
	var reputation_before := GameState.reputation
	var hearts_before := GameState.hearts

	watch_signals(EventBus)
	Clock.force_advance_ticks(MARLON_DINNER_TICKS + 5)

	assert_true(Sim.walkin_queue.is_empty(), "Marlon should have served the Walk-in Diner")
	var expected_score := Satisfaction.compute_dining(true, MARLON_KITCHEN_SKILL, GameState.balance)
	assert_eq(expected_score, 85.0, "base 50 + the 20 special-match bonus + skill 3 * 5 per level")

	assert_signal_emit_count(EventBus, "dining_guest_served", 1)
	var params: Array = get_signal_parameters(EventBus, "dining_guest_served")
	assert_eq(params[2], "positive")
	assert_eq(params[3], expected_score)

	assert_eq(GameState.hearts, hearts_before + Satisfaction.hearts_for(expected_score, GameState.balance))
	assert_eq(GameState.reputation, reputation_before + int(GameState.balance["review"]["reputation_delta_positive"]))


func test_served_walkin_diner_without_a_special_match_can_score_neutral_with_no_hearts() -> void:
	Sim.assign_staffer("marlon", "kitchen")
	Clock.force_advance_ticks(EVENING_START_TICK)
	Sim.walkin_queue.clear()
	assert_eq(GameState.daily_special, "", "no Daily Special chosen -- this Walk-in Diner can never match")
	_push_walkin(1, 999.0, "test_species")
	var reputation_before := GameState.reputation
	var hearts_before := GameState.hearts

	watch_signals(EventBus)
	Clock.force_advance_ticks(MARLON_DINNER_TICKS + 5)

	assert_true(Sim.walkin_queue.is_empty(), "Marlon should have served the Walk-in Diner")
	var expected_score := Satisfaction.compute_dining(false, MARLON_KITCHEN_SKILL, GameState.balance)
	assert_eq(expected_score, 65.0, "base 50 + no match bonus + skill 3 * 5 per level")

	assert_signal_emitted_with_parameters(EventBus, "dining_guest_served", ["Test Diner 1", "test_species", "neutral", expected_score])
	assert_eq(GameState.hearts, hearts_before, "a 65 score sits below the 70 Hearts threshold")
	assert_eq(GameState.reputation, reputation_before, "a neutral review carries no Reputation delta")


## --- A Walk-in Diner whose Patience expires unserved costs Reputation, same as a lost Room-booking Party ---

func test_walkin_diner_patience_expiry_costs_reputation_like_a_room_booking_walkaway() -> void:
	Clock.force_advance_ticks(EVENING_START_TICK) # Evening starts, Kitchen left unstaffed
	Sim.walkin_queue.clear()
	_push_walkin(1, 2.0) # balance.json's dining.walkin_patience.decay_per_tick is 1/tick
	var reputation_before := GameState.reputation

	watch_signals(EventBus)
	Clock.force_advance_ticks(2)

	assert_true(Sim.walkin_queue.is_empty(), "a Walk-in Diner whose Patience hits zero should walk away")
	assert_signal_emit_count(EventBus, "dining_guest_walked_away", 1)
	assert_eq(GameState.reputation, reputation_before + int(GameState.balance["review"]["reputation_delta_walkaway"]))
