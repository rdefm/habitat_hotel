extends "res://tests/helpers/sim_test_base.gd"

## Characterizes the Terrace's Evening Walk-in Diner queue + Daily Special
## (ADR-0003, ticket 10): Walk-in Diners arrive only during the Evening
## phase on their own independent Patience-timered queue (Sim.walkin_queue,
## separate from Sim.pending_arrivals), the player's chosen Daily Special
## (GameState.daily_special) measurably biases which Species show up
## (DemandGenerator.pick_walkin_species()), and serving them requires a
## higher Kitchen skill threshold than breakfast --
## data/balance.json's stations.kitchen.dinner_min_skill (3) sits above
## breakfast_min_skill (2): Biscuit's kitchen skill (1) sits below both,
## Shelly's (2) clears breakfast only, Marlon's (3) clears both (see
## data/staffers.json). See
## .scratch/direct-manipulation-core-loop/issues/10-walk-in-dinner-daily-special.md.
##
## Starting hotel (data/starting_hotel.json): cozy_nook#0 (capacity 2, tags
## warm/dry/quiet), roost_loft#0 (capacity 4, tags high_perch/dry).
## Clock phase boundaries (autoload/clock.gd): EVENING starts at tick 161.

const DemandGenerator = preload("res://sim/demand_generator.gd")

const DINNER_MIN_SKILL := 3 # balance.json's stations.kitchen.dinner_min_skill
const MARLON_BREAKFAST_TICKS := 16 # balance.json's breakfast_ticks_by_skill, skill 3
const MARLON_DINNER_TICKS := 22 # balance.json's dinner_ticks_by_skill, skill 3
const SHELLY_BREAKFAST_TICKS := 20 # balance.json's breakfast_ticks_by_skill, skill 2
const EVENING_START_TICK := 161


func _seat(party_id: int, room_type_id: String, instance_id: int, needs: Array) -> void:
	Sim.pending_arrivals.append(make_party(party_id, needs, 1))
	Sim.seat_party(party_id, room_type_id, instance_id)


func _push_walkin(id: int, patience: float, species_id: String = "test_species") -> void:
	Sim.walkin_queue.append({
		"id": id,
		"name": "Test Diner %d" % id,
		"species_id": species_id,
		"party_size": 1,
		"patience": patience,
	})


## --- Walk-in Diners arrive only during Evening, on an independent queue ---

func test_walkin_queue_is_empty_before_evening() -> void:
	Clock.force_advance_ticks(EVENING_START_TICK - 1) # through the end of Midday
	assert_true(Sim.walkin_queue.is_empty(), "Walk-in Diners shouldn't arrive before the Evening phase")


func test_walkin_queue_populates_the_moment_evening_starts() -> void:
	Clock.force_advance_ticks(EVENING_START_TICK)
	assert_false(Sim.walkin_queue.is_empty(), "Evening's start should populate the Walk-in queue")


func test_walkin_queue_is_independent_of_the_room_booking_queue() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	Clock.force_advance_ticks(EVENING_START_TICK)
	assert_true(Sim.pending_arrivals.is_empty(), "Evening force-clears the Room-booking queue")
	assert_false(Sim.walkin_queue.is_empty(), "the Walk-in queue is a separate array, unaffected by the Room-booking queue's clear")
	for entry in Sim.walkin_queue:
		assert_true(entry.has("patience"), "each Walk-in Diner carries its own Patience")


## --- Daily Special biases Walk-in species ---

func test_daily_special_can_be_set_and_cleared() -> void:
	assert_true(GameState.set_daily_special("pigeon"))
	assert_eq(GameState.daily_special, "pigeon")
	assert_true(GameState.set_daily_special(""))
	assert_eq(GameState.daily_special, "")


func test_daily_special_rejects_an_unknown_species() -> void:
	assert_false(GameState.set_daily_special("dragon"))
	assert_eq(GameState.daily_special, "", "an unknown species id should leave the Daily Special unchanged")


func test_daily_special_measurably_biases_walkin_species() -> void:
	var dining: Dictionary = GameState.balance["dining"]
	var draws := 200
	var special_hits := 0
	for i in range(draws):
		var s := DemandGenerator.pick_walkin_species(GameState.species, "pigeon", dining, Rng)
		if s["id"] == "pigeon":
			special_hits += 1
	# Uniform baseline across data/species.json's 8 entries is ~12.5%; the
	# Daily Special's bias_chance (0.5) alone should push this well past a
	# generous margin above that baseline.
	assert_true(special_hits > draws / 3, "the Daily Special should noticeably raise its Species' pick rate (got %d/%d)" % [special_hits, draws])


## --- Kitchen skill gates who can serve dinner/Walk-in demand ---

func test_kitchen_staffer_above_dinner_threshold_serves_both_breakfast_and_walkin() -> void:
	assert_true(int(GameState.staffers["marlon"]["skills"]["kitchen"]) >= DINNER_MIN_SKILL, "test assumes Marlon meets the dinner threshold")
	Sim.assign_staffer("marlon", "kitchen")
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	_push_walkin(999, 999.0) # patience won't expire within this test's window

	Clock.force_advance_ticks(MARLON_BREAKFAST_TICKS + MARLON_DINNER_TICKS + 5) # comfortably past both jobs, still well before Evening (161)

	assert_true(Sim.breakfast_queue.is_empty(), "Marlon should have served breakfast")
	assert_true(Sim.walkin_queue.is_empty(), "Marlon should also have served the Walk-in Diner")


func test_kitchen_staffer_above_breakfast_but_below_dinner_serves_breakfast_only() -> void:
	var shelly_skill := int(GameState.staffers["shelly"]["skills"]["kitchen"])
	assert_true(shelly_skill < DINNER_MIN_SKILL, "test assumes Shelly sits below the dinner threshold")
	Sim.assign_staffer("shelly", "kitchen")
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	_push_walkin(999, 999.0)

	Clock.force_advance_ticks(SHELLY_BREAKFAST_TICKS + 20) # comfortably past breakfast, still nowhere near Evening

	assert_true(Sim.breakfast_queue.is_empty(), "Shelly clears the breakfast threshold")
	assert_eq(Sim.walkin_queue.size(), 1, "Shelly sits below the dinner threshold and should never claim the Walk-in Diner")
	assert_true(Sim.dinner_job("shelly").is_empty())


func test_reassigning_a_kitchen_staffer_mid_dinner_job_interrupts_only_their_job() -> void:
	Sim.assign_staffer("shelly", "kitchen") # skill 2, breakfast only
	Sim.assign_staffer("marlon", "kitchen") # skill 3, clears the dinner threshold too
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	_push_walkin(1, 999.0)

	Clock.force_advance_ticks(1) # Day 1's Morning: Shelly claims breakfast, Marlon claims the Walk-in Diner
	assert_false(Sim.breakfast_job("shelly").is_empty(), "Shelly should have claimed the breakfast entry")
	assert_false(Sim.dinner_job("marlon").is_empty(), "Marlon should have claimed the only Walk-in Diner")
	var shelly_entry_id: int = int(Sim.breakfast_job("shelly")["entry_id"])
	var shelly_ticks_before: int = int(Sim.breakfast_job("shelly")["ticks_remaining"])

	Sim.assign_staffer("marlon", "reception") # interrupt only Marlon's dinner job

	assert_true(Sim.dinner_job("marlon").is_empty(), "Marlon's in-flight dinner job should be dropped")
	assert_eq(Sim.walkin_queue.size(), 1, "the interrupted Walk-in Diner goes back to waiting, not removed")
	var shelly_job_after := Sim.breakfast_job("shelly")
	assert_eq(int(shelly_job_after["entry_id"]), shelly_entry_id, "Shelly's own breakfast job shouldn't be touched")
	assert_eq(int(shelly_job_after["ticks_remaining"]), shelly_ticks_before)


## --- Patience expiry ---

func test_walkin_diner_whose_patience_expires_unserved_walks_away() -> void:
	Clock.force_advance_ticks(EVENING_START_TICK) # Evening starts, Kitchen left unstaffed
	Sim.walkin_queue.clear()
	_push_walkin(1, 2.0) # balance.json's dining.walkin_patience.decay_per_tick is 1/tick

	Clock.force_advance_ticks(2)

	assert_true(Sim.walkin_queue.is_empty(), "a Walk-in Diner whose Patience hits zero should walk away")


func test_walkin_diner_with_ample_patience_stays_queued() -> void:
	Clock.force_advance_ticks(EVENING_START_TICK)
	Sim.walkin_queue.clear()
	_push_walkin(1, 999.0)

	Clock.force_advance_ticks(2)

	assert_eq(Sim.walkin_queue.size(), 1, "a Walk-in Diner with plenty of Patience left shouldn't walk away")


## --- An unstaffed Kitchen burns Walk-in Patience faster (CONTEXT.md's Patience entry) ---

func test_walkin_patience_decays_faster_when_kitchen_is_unstaffed() -> void:
	var patience_cfg: Dictionary = GameState.balance["dining"]["walkin_patience"]
	var decay: float = float(patience_cfg["decay_per_tick"])
	var multiplier: float = float(patience_cfg["unstaffed_multiplier"])
	Clock.force_advance_ticks(EVENING_START_TICK) # Kitchen left unstaffed
	Sim.walkin_queue.clear()
	_push_walkin(1, 100.0)

	Clock.force_advance_ticks(1)

	assert_eq(float(Sim.walkin_queue[0]["patience"]), 100.0 - decay * multiplier, "an unstaffed Kitchen should burn Patience at the multiplied rate")


func test_walkin_patience_decays_at_base_rate_when_kitchen_is_staffed() -> void:
	var decay: float = float(GameState.balance["dining"]["walkin_patience"]["decay_per_tick"])
	Sim.assign_staffer("biscuit", "kitchen") # present, even though skill 1 can't actually serve dinner
	Clock.force_advance_ticks(EVENING_START_TICK)
	Sim.walkin_queue.clear()
	_push_walkin(1, 100.0)

	Clock.force_advance_ticks(1)

	assert_eq(float(Sim.walkin_queue[0]["patience"]), 100.0 - decay, "a staffed Kitchen (even below the dinner threshold) shouldn't apply the unstaffed multiplier")
