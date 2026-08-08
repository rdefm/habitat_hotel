extends "res://tests/helpers/sim_test_base.gd"

## Characterizes ticket 13 (ADR-0003): the Terrace gets an upgrades list the
## same shape as a Room's -- purchasable with cash/Hearts via
## GameState.purchase_terrace_upgrade(), queryable via
## GameState.available_terrace_upgrades()/effective_terrace_stats(), and
## persisting exactly like a Room instance's "upgrades" Array (reset only by
## GameState.reset_to_starting_conditions()). A purchased upgrade's effects
## feed Dining outcomes the same way a Room upgrade feeds a stay:
## satisfaction_bonus into Satisfaction.compute_dining()'s score
## (Sim._serve_walkin_diner()), capacity_delta into the Walk-in count range
## (Sim._populate_walkin_queue()), and upkeep_delta into the nightly upkeep
## bill (Sim._do_night()). See data/terrace.json for the real catalog:
## seasoned_recipes (satisfaction_bonus 10, 600 cash/8 hearts), extra_seating
## (capacity_delta 1, 700 cash/6 hearts), outdoor_awning (upkeep_delta -4,
## 500 cash/5 hearts). data/balance.json's dining.walkin_count_min/max are
## 1/3; the starting terrace.upkeep_per_day is 10.
##
## Clock phase boundaries (autoload/clock.gd): EVENING starts at tick 161,
## NIGHT at tick 221. Starting roster: Marlon (kitchen skill 3) is the only
## starting Staffer who clears stations.kitchen.dinner_min_skill (3).

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


## --- Catalog/purchase queries, mirroring the Room upgrade contract ---

func test_available_terrace_upgrades_lists_the_full_catalog_before_any_purchase() -> void:
	var available := GameState.available_terrace_upgrades()
	var ids: Array = available.map(func(u): return u["id"])
	assert_true(ids.has("seasoned_recipes"))
	assert_true(ids.has("extra_seating"))
	assert_true(ids.has("outdoor_awning"))


func test_purchase_terrace_upgrade_deducts_cash_and_hearts_and_marks_it_purchased() -> void:
	GameState.hearts = 20
	var cash_before := GameState.cash

	var bought := GameState.purchase_terrace_upgrade("seasoned_recipes")

	assert_true(bought)
	assert_eq(GameState.cash, cash_before - 600)
	assert_eq(GameState.hearts, 20 - 8)
	assert_true(GameState.terrace_upgrades.has("seasoned_recipes"))
	var ids: Array = GameState.available_terrace_upgrades().map(func(u): return u["id"])
	assert_false(ids.has("seasoned_recipes"), "a purchased upgrade should drop out of the available list")


func test_purchase_terrace_upgrade_fails_for_an_unknown_id() -> void:
	var cash_before := GameState.cash

	var bought := GameState.purchase_terrace_upgrade("nonexistent")

	assert_false(bought)
	assert_eq(GameState.cash, cash_before)
	assert_true(GameState.terrace_upgrades.is_empty())


func test_purchase_terrace_upgrade_fails_when_already_purchased() -> void:
	GameState.hearts = 20
	assert_true(GameState.purchase_terrace_upgrade("seasoned_recipes"))
	var cash_before := GameState.cash

	var bought_again := GameState.purchase_terrace_upgrade("seasoned_recipes")

	assert_false(bought_again, "buying the same Terrace upgrade twice should refuse")
	assert_eq(GameState.cash, cash_before, "no double-charge on a refused repurchase")


func test_purchase_terrace_upgrade_fails_when_cash_insufficient() -> void:
	GameState.cash = 100
	GameState.hearts = 20

	var bought := GameState.purchase_terrace_upgrade("seasoned_recipes")

	assert_false(bought)
	assert_eq(GameState.cash, 100)
	assert_true(GameState.terrace_upgrades.is_empty())


func test_purchase_terrace_upgrade_fails_when_hearts_insufficient() -> void:
	GameState.hearts = 0
	var cash_before := GameState.cash

	var bought := GameState.purchase_terrace_upgrade("seasoned_recipes")

	assert_false(bought)
	assert_eq(GameState.cash, cash_before)
	assert_true(GameState.terrace_upgrades.is_empty())


## --- Purchased upgrades persist, and merge into effective_terrace_stats() ---

func test_purchased_terrace_upgrades_persist_and_are_queryable() -> void:
	GameState.hearts = 20
	GameState.purchase_terrace_upgrade("seasoned_recipes")
	GameState.purchase_terrace_upgrade("extra_seating")

	assert_eq(GameState.terrace_upgrades, ["seasoned_recipes", "extra_seating"])


func test_reset_to_starting_conditions_clears_purchased_terrace_upgrades() -> void:
	GameState.hearts = 20
	GameState.purchase_terrace_upgrade("seasoned_recipes")

	GameState.reset_to_starting_conditions()

	assert_true(GameState.terrace_upgrades.is_empty(), "a fresh game shouldn't carry over the prior run's Terrace upgrades")


func test_effective_terrace_stats_defaults_match_the_unmodified_base() -> void:
	var stats := GameState.effective_terrace_stats()
	assert_eq(int(stats["upkeep_per_day"]), 10)
	assert_eq(int(stats["capacity_delta"]), 0)
	assert_eq(float(stats["satisfaction_bonus"]), 0.0)


func test_effective_terrace_stats_merges_every_purchased_upgrades_effects() -> void:
	GameState.hearts = 20
	GameState.purchase_terrace_upgrade("seasoned_recipes") # satisfaction_bonus +10
	GameState.purchase_terrace_upgrade("extra_seating") # capacity_delta +1
	GameState.purchase_terrace_upgrade("outdoor_awning") # upkeep_delta -4

	var stats := GameState.effective_terrace_stats()

	assert_eq(float(stats["satisfaction_bonus"]), 10.0)
	assert_eq(int(stats["capacity_delta"]), 1)
	assert_eq(int(stats["upkeep_per_day"]), 6, "base 10 upkeep - 4 from outdoor_awning")


## --- satisfaction_bonus feeds a served Walk-in Diner's dining score ---

func test_satisfaction_bonus_upgrade_raises_a_served_walkin_diners_score() -> void:
	GameState.hearts = 20
	GameState.purchase_terrace_upgrade("seasoned_recipes") # satisfaction_bonus +10
	Sim.assign_staffer("marlon", "kitchen")
	Clock.force_advance_ticks(EVENING_START_TICK)
	Sim.walkin_queue.clear()
	_push_walkin(1, 999.0)

	watch_signals(EventBus)
	Clock.force_advance_ticks(MARLON_DINNER_TICKS + 5)

	assert_true(Sim.walkin_queue.is_empty(), "Marlon should have served the Walk-in Diner")
	var expected_score := Satisfaction.compute_dining(false, MARLON_KITCHEN_SKILL, GameState.balance, 10.0)
	assert_signal_emitted_with_parameters(EventBus, "dining_guest_served", ["Test Diner 1", "test_species", "positive", expected_score])


## --- capacity_delta widens the Walk-in count range ---

func test_capacity_delta_upgrade_widens_the_evenings_walkin_queue_range() -> void:
	GameState.hearts = 20
	GameState.purchase_terrace_upgrade("extra_seating") # capacity_delta +1
	var dining: Dictionary = GameState.balance["dining"]
	var expected_min: int = int(dining["walkin_count_min"]) + 1
	var expected_max: int = int(dining["walkin_count_max"]) + 1

	Clock.force_advance_ticks(EVENING_START_TICK)

	assert_between(Sim.walkin_queue.size(), expected_min, expected_max, "the Walk-in queue size should be drawn from the widened range")


## --- upkeep_delta folds into the nightly upkeep bill ---

func test_upkeep_delta_upgrade_reduces_the_nightly_upkeep_bill() -> void:
	GameState.hearts = 20
	GameState.purchase_terrace_upgrade("outdoor_awning") # upkeep_delta -4
	var room_upkeep := 0
	for room in GameState.hotel_rooms:
		room_upkeep += int(GameState.effective_room_stats(room)["upkeep_per_day"])
	var wage: int = int(GameState.balance["costs"]["staff_wage_per_day"])
	var cash_before := GameState.cash

	Clock.force_advance_ticks(221) # through Night

	var expected_terrace_upkeep := 10 - 4
	assert_eq(GameState.cash, cash_before - (room_upkeep + expected_terrace_upkeep + wage))
