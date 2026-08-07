extends "res://tests/helpers/sim_test_base.gd"

## Characterizes the Terrace's breakfast service loop (ADR-0003, ticket 09):
## the Terrace is a fixed structure present and functioning from Day 1, no
## build or unlock action required, exactly like Reception. Every
## currently-staying guest joins Sim.breakfast_queue fresh each Morning, and
## a Kitchen Staffer serves queued entries only at/above
## data/balance.json's stations.kitchen.breakfast_min_skill -- Biscuit's
## kitchen skill (1) sits below that threshold; Shelly's (2) and Marlon's
## (3) sit at/above it (see data/staffers.json). See
## .scratch/direct-manipulation-core-loop/issues/09-terrace-breakfast.md.
##
## Starting hotel (data/starting_hotel.json): cozy_nook#0 (capacity 2, tags
## warm/dry/quiet), roost_loft#0 (capacity 4, tags high_perch/dry).

const BREAKFAST_MIN_SKILL := 2 # balance.json's stations.kitchen.breakfast_min_skill
const SHELLY_BREAKFAST_TICKS := 20 # balance.json's stations.kitchen, skill 2


func _seat(party_id: int, room_type_id: String, instance_id: int, needs: Array) -> void:
	Sim.pending_arrivals.append(make_party(party_id, needs, 1))
	Sim.seat_party(party_id, room_type_id, instance_id)


## --- The Terrace needs no build/unlock ---

func test_terrace_operates_from_day_one_with_no_build_or_unlock_needed() -> void:
	assert_eq(GameState.stars, 1, "Day 1 starts at 1 star, well below any hypothetical unlock")
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])

	Clock.force_advance_ticks(1) # Day 1's Morning -- no build/unlock action taken
	assert_eq(Sim.breakfast_queue.size(), 1, "the Terrace served this guest on Day 1 with no build or unlock")


## --- Every currently-staying guest joins the queue each Morning ---

func test_every_staying_guest_joins_the_breakfast_queue_each_morning() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	_seat(2, "roost_loft", 0, ["high_perch", "dry"])

	Clock.force_advance_ticks(1) # Day 1's Morning

	assert_eq(Sim.breakfast_queue.size(), 2)
	var room_keys: Array = Sim.breakfast_queue.map(func(e): return "%s#%d" % [e["room_type_id"], int(e["instance_id"])])
	assert_true(room_keys.has("cozy_nook#0"))
	assert_true(room_keys.has("roost_loft#0"))


func test_breakfast_queue_repopulates_fresh_each_morning() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	Clock.force_advance_ticks(1) # Day 1's Morning
	var day1_entry_id: int = int(Sim.breakfast_queue[0]["id"])

	Clock.force_advance_ticks(Clock.TICKS_PER_DAY - 1) # carries through to Day 2's Morning

	assert_eq(Sim.breakfast_queue.size(), 1, "the still-staying guest should rejoin the queue on Day 2")
	assert_ne(int(Sim.breakfast_queue[0]["id"]), day1_entry_id, "Day 2's entry should be freshly created, not carried over")


## --- Kitchen skill gates who can serve breakfast ---

func test_kitchen_staffer_at_or_above_threshold_serves_breakfast() -> void:
	assert_true(int(GameState.staffers["shelly"]["skills"]["kitchen"]) >= BREAKFAST_MIN_SKILL, "test assumes Shelly meets the breakfast threshold")
	Sim.assign_staffer("shelly", "kitchen")
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])

	Clock.force_advance_ticks(SHELLY_BREAKFAST_TICKS)

	assert_true(Sim.breakfast_queue.is_empty(), "an at-threshold Kitchen Staffer should have served this guest by now")


func test_kitchen_staffer_below_threshold_cannot_serve_breakfast() -> void:
	assert_true(int(GameState.staffers["biscuit"]["skills"]["kitchen"]) < BREAKFAST_MIN_SKILL, "test assumes Biscuit sits below the breakfast threshold")
	Sim.assign_staffer("biscuit", "kitchen")
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])

	Clock.force_advance_ticks(SHELLY_BREAKFAST_TICKS * 3) # comfortably longer than any real serve time

	assert_eq(Sim.breakfast_queue.size(), 1, "a below-threshold Kitchen Staffer should never pick up a breakfast job")
	assert_true(Sim.breakfast_job("biscuit").is_empty())


func test_empty_kitchen_station_means_no_breakfast_served() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])

	Clock.force_advance_ticks(SHELLY_BREAKFAST_TICKS * 3)

	assert_eq(Sim.breakfast_queue.size(), 1, "no Kitchen Staffer assigned -- the queue should never drain")


## --- Reassigning a Kitchen Staffer mid-job interrupts only their job ---

func test_reassigning_a_kitchen_staffer_mid_job_interrupts_only_their_job() -> void:
	Sim.assign_staffer("shelly", "kitchen") # skill 2
	Sim.assign_staffer("marlon", "kitchen") # skill 3
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	_seat(2, "roost_loft", 0, ["high_perch", "dry"])

	Clock.force_advance_ticks(1) # Day 1's Morning, both Staffers claim an entry
	assert_false(Sim.breakfast_job("shelly").is_empty())
	assert_false(Sim.breakfast_job("marlon").is_empty())
	var marlon_entry_id: int = int(Sim.breakfast_job("marlon")["entry_id"])
	var marlon_ticks_before: int = int(Sim.breakfast_job("marlon")["ticks_remaining"])

	Sim.assign_staffer("shelly", "reception") # interrupt only Shelly's job

	assert_true(Sim.breakfast_job("shelly").is_empty(), "Shelly's in-flight job should be dropped")
	var marlon_job_after := Sim.breakfast_job("marlon")
	assert_eq(int(marlon_job_after["entry_id"]), marlon_entry_id, "Marlon's own job shouldn't be touched")
	assert_eq(int(marlon_job_after["ticks_remaining"]), marlon_ticks_before)
	assert_eq(Sim.breakfast_queue.size(), 2, "the interrupted entry goes back to waiting, not removed")
