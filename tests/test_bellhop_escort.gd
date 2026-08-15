extends "res://tests/helpers/sim_test_base.gd"

## Characterizes the Bellhop Escort mechanic (ADR-0014/0017, ticket 01): a
## staffed Bellhop no longer seats a Party instantly -- each assigned,
## currently-idle Bellhop Staffer claims the next Room awaiting Escort and
## works it down over a Skill-scaled per-Staffer Job, mirroring
## Housekeeping's parallel per-Staffer cleaning Jobs (ADR-0008) rather than
## Bellhop's old presence-only check. A Room seated while every assigned
## Bellhop is already mid-Escort waits (still "checking_in", not walked away)
## until one frees up. The unstaffed case's flat
## stations.bellhop.unstaffed_checkin_delay_ticks delay is untouched -- see
## test_roster_station.gd's test_empty_bellhop_station_measurably_slows_check_in_versus_staffed().
##
## A Room's data (guests[gid], room["occupant"]) is written at admission time
## regardless of Escort -- "waiting-for-Bellhop" describes the visible
## checking_in/escort_mode flags, same as the pre-existing unstaffed flat
## delay already worked (see sim_controller.gd's _admit_guest()/_start_checkin()).
##
## Starting hotel (data/starting_hotel.json): cozy_nook#0 (warm/dry/quiet),
## roost_loft#0 (high_perch/dry), lagoon_room#0/#1 (warm/water). Default
## Station coverage: Biscuit/Reception, Marlon/Bellhop, Shelly/Housekeeping,
## Kitchen empty. Bellhop skills (data/staffers.json): Biscuit 2, Marlon 5,
## Shelly 1.

const BatchRunner = preload("res://sim/batch_runner.gd")
const ESCORT_TICKS_BY_SKILL: Dictionary = {"1": 20, "2": 16, "3": 12, "4": 9, "5": 6} # balance.json
const BELLHOP_UNSTAFFED_DELAY_TICKS := 16 # balance.json's stations.bellhop


func _seat(party_id: int, room_type_id: String, instance_id: int, needs: Array) -> void:
	Sim.pending_arrivals.append(make_party(party_id, needs, 1))
	Sim.seat_party(party_id, room_type_id, instance_id)


## --- Skill scales the Escort delay ---

func test_escort_resolves_in_exactly_the_table_entrys_ticks_at_skill_1() -> void:
	Sim.assign_staffer("marlon", "kitchen") # empty Bellhop
	Sim.assign_staffer("shelly", "bellhop") # sole Bellhop, skill 1
	_seat(1, "lagoon_room", 0, ["warm", "water"])

	Clock.force_advance_ticks(ESCORT_TICKS_BY_SKILL["1"] - 1)
	assert_true(GameState.room_instance("lagoon_room", 0)["checking_in"], "skill 1's Escort shouldn't have resolved yet")
	Clock.force_advance_ticks(1)
	assert_false(GameState.room_instance("lagoon_room", 0)["checking_in"], "skill 1's Escort should resolve after exactly its table entry's ticks")


func test_escort_at_skill_5_resolves_measurably_faster_than_at_skill_1() -> void:
	_seat(1, "lagoon_room", 0, ["warm", "water"]) # Marlon (default Bellhop, skill 5) escorts

	Clock.force_advance_ticks(ESCORT_TICKS_BY_SKILL["5"] - 1)
	assert_true(GameState.room_instance("lagoon_room", 0)["checking_in"], "skill 5's Escort shouldn't have resolved yet either")
	Clock.force_advance_ticks(1)
	assert_false(GameState.room_instance("lagoon_room", 0)["checking_in"], "skill 5's Escort resolves in far fewer ticks than skill 1's")


## --- Two assigned Bellhops escort different Parties in parallel ---

func test_two_assigned_bellhops_can_each_escort_a_different_party_at_once() -> void:
	Sim.assign_staffer("biscuit", "bellhop") # now Marlon + Biscuit both Bellhop
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	_seat(2, "roost_loft", 0, ["high_perch", "dry"])

	Clock.force_advance_ticks(1) # both Staffers claim a Room and tick down once

	assert_eq(Sim.escort_staffers("cozy_nook", 0), ["marlon"], "the earlier Room in hotel_rooms order is claimed first")
	assert_eq(Sim.escort_staffers("roost_loft", 0), ["biscuit"])
	assert_eq(int(Sim.escort_job("marlon")["ticks_remaining"]), ESCORT_TICKS_BY_SKILL["5"] - 1)
	assert_eq(int(Sim.escort_job("biscuit")["ticks_remaining"]), ESCORT_TICKS_BY_SKILL["2"] - 1)


## --- Waiting-for-Bellhop queue ---

func test_a_party_seated_while_every_assigned_bellhop_is_busy_waits_rather_than_falling_back_to_flat_delay() -> void:
	# Only Marlon is assigned to Bellhop; both Parties are seated before any
	# tick runs, so both Rooms start out unclaimed together.
	_seat(1, "lagoon_room", 0, ["warm", "water"])
	_seat(2, "lagoon_room", 1, ["warm", "water"])

	Clock.force_advance_ticks(1) # Marlon claims the first unclaimed Room in hotel_rooms order

	assert_eq(Sim.escort_staffers("lagoon_room", 0), ["marlon"])
	var waiting_room := GameState.room_instance("lagoon_room", 1)
	assert_true(Sim.escort_staffers("lagoon_room", 1).is_empty(), "no Bellhop is free to claim the second Room yet")
	assert_true(waiting_room["checking_in"], "a waiting Room is still mid check-in, not walked away")
	assert_not_null(waiting_room["occupant"], "the Party was already admitted -- waiting-for-Bellhop is a visible state, not an unseated one")


func test_a_waiting_party_is_picked_up_automatically_once_a_bellhop_frees_up() -> void:
	_seat(1, "lagoon_room", 0, ["warm", "water"])
	_seat(2, "lagoon_room", 1, ["warm", "water"])

	Clock.force_advance_ticks(ESCORT_TICKS_BY_SKILL["5"]) # Marlon claims + finishes lagoon_room#0
	assert_false(GameState.room_instance("lagoon_room", 0)["checking_in"])
	assert_true(Sim.escort_staffers("lagoon_room", 1).is_empty(), "Marlon's completed job is only erased at the end of that tick, so the claim happens next tick")

	Clock.force_advance_ticks(1) # Marlon, now free, claims the waiting Room
	assert_eq(Sim.escort_staffers("lagoon_room", 1), ["marlon"])
	assert_eq(int(Sim.escort_job("marlon")["ticks_remaining"]), ESCORT_TICKS_BY_SKILL["5"] - 1, "a freshly claimed Job looks Skill up fresh, no partial credit from the earlier Room")


## --- Reassignment interrupts only the moved Staffer's own Escort ---

func test_reassigning_a_mid_escort_bellhop_interrupts_only_their_own_escort() -> void:
	Sim.assign_staffer("biscuit", "bellhop") # Marlon + Biscuit both Bellhop
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	_seat(2, "roost_loft", 0, ["high_perch", "dry"])
	Clock.force_advance_ticks(1) # Marlon claims cozy_nook, Biscuit claims roost_loft
	var biscuit_ticks_before: int = int(Sim.escort_job("biscuit")["ticks_remaining"])

	Sim.assign_staffer("marlon", "kitchen") # interrupt only Marlon's Escort; Biscuit remains assigned to Bellhop

	assert_true(Sim.escort_job("marlon").is_empty(), "Marlon's in-flight Escort should be dropped")
	assert_eq(int(Sim.escort_job("biscuit")["ticks_remaining"]), biscuit_ticks_before, "Biscuit's own progress shouldn't be touched")

	var marlons_room := GameState.room_instance("cozy_nook", 0)
	assert_true(marlons_room["checking_in"], "Marlon's Room stays mid check-in")
	assert_true(marlons_room["escort_mode"], "Bellhop (Biscuit) is still staffed, so it waits for the next free Bellhop rather than falling back")
	assert_true(Sim.escort_staffers("cozy_nook", 0).is_empty(), "nobody is currently escorting Marlon's abandoned Room")
	assert_eq(Sim.escort_staffers("roost_loft", 0), ["biscuit"], "Biscuit's Room is untouched by Marlon's reassignment")


func test_reassigning_the_last_assigned_bellhop_mid_escort_falls_back_to_unstaffed_behavior() -> void:
	_seat(1, "lagoon_room", 0, ["warm", "water"]) # Marlon is the only assigned Bellhop
	Clock.force_advance_ticks(1) # Marlon claims it

	Sim.assign_staffer("marlon", "kitchen") # empties Bellhop entirely, mid-Escort
	Clock.force_advance_ticks(1) # the next tick notices Bellhop is unstaffed and falls back

	var room := GameState.room_instance("lagoon_room", 0)
	assert_true(room["checking_in"])
	assert_false(room["escort_mode"], "no Bellhop remains assigned, so this Room falls back to the flat unstaffed delay")
	assert_eq(int(room["checkin_ticks_remaining"]), BELLHOP_UNSTAFFED_DELAY_TICKS, "the fallback starts the flat delay fresh, no partial credit for Escort ticks already spent")

	Clock.force_advance_ticks(BELLHOP_UNSTAFFED_DELAY_TICKS)
	assert_false(GameState.room_instance("lagoon_room", 0)["checking_in"], "the flat delay still resolves on its own")


## --- Liveness: no Party can be left stuck in an unresolvable Escort-wait ---

func test_no_room_is_left_stuck_across_a_full_bellhop_staffing_churn() -> void:
	_seat(1, "lagoon_room", 0, ["warm", "water"])
	_seat(2, "lagoon_room", 1, ["warm", "water"])
	Clock.force_advance_ticks(1) # Marlon claims lagoon_room#0; #1 waits

	Sim.assign_staffer("marlon", "kitchen") # empties Bellhop entirely, mid-Escort and mid-wait at once
	Clock.force_advance_ticks(1) # both Rooms fall back to the flat unstaffed delay

	for room in [GameState.room_instance("lagoon_room", 0), GameState.room_instance("lagoon_room", 1)]:
		assert_false(room["escort_mode"])
		assert_eq(int(room["checkin_ticks_remaining"]), BELLHOP_UNSTAFFED_DELAY_TICKS)

	Sim.assign_staffer("marlon", "bellhop") # re-staffing doesn't yank already-fallen-back Rooms back into Escort mode
	Clock.force_advance_ticks(BELLHOP_UNSTAFFED_DELAY_TICKS)

	assert_false(GameState.room_instance("lagoon_room", 0)["checking_in"], "no Room should be left stuck after the churn resolves")
	assert_false(GameState.room_instance("lagoon_room", 1)["checking_in"], "no Room should be left stuck after the churn resolves")


## A full multi-day headless run (BatchRunner, same tool
## test_integration_multiday.gd's checks use), with Bellhop staffed by
## default coverage's Marlon the whole run -- every seated Party's Escort
## should always resolve, never leave a Room stranded waiting on a Bellhop
## that will never come. Only characterizes the Escort-specific invariant --
## general Party-stranding is test_integration_multiday.gd's concern, not
## this ticket's.
func test_a_60_day_batch_run_leaves_no_room_stuck_in_an_unresolvable_escort_wait() -> void:
	var rows := BatchRunner.run(60, "user://test_bellhop_escort_batch.csv", 12345)

	assert_eq(rows.size(), 60)
	for room in GameState.hotel_rooms:
		var unclaimed: bool = room.get("checking_in", false) and room.get("escort_mode", false) and Sim.escort_staffers(room["room_type_id"], int(room["instance_id"])).is_empty()
		var stuck: bool = unclaimed and not GameState.is_station_staffed("bellhop")
		assert_false(stuck, "a waiting Room with no Bellhop left assigned and no fallback triggered would be stuck forever")
