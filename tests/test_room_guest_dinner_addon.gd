extends "res://tests/helpers/sim_test_base.gd"

## Characterizes ticket 12 (room-guest dinner add-on): a Party can opt into a
## dinner add-on as part of being seated (Sim.seat_party()'s new dinner_addon
## param), an occupied Room's card indicator (GameState room dict's
## occupant_dinner_addon) tracks it until that evening resolves it, and the
## add-on joins the exact same Evening dinner queue/Kitchen-skill gating and
## Reputation/Hearts scoring a Walk-in Diner already goes through (ticket 10/
## 11) -- Sim._populate_walkin_queue() tags a room-guest's entry with
## guest_id (a true Walk-in Diner has none), and Sim._serve_walkin_diner()/
## _decay_walkin_patience() clear the guest's/room's dinner_addon flag on
## resolution via _resolve_room_guest_addon(). See
## .scratch/direct-manipulation-core-loop/issues/12-room-guest-dinner-addon.md.
##
## Starting hotel (data/starting_hotel.json): cozy_nook#0 (capacity 2, tags
## warm/dry/quiet), roost_loft#0 (capacity 4, tags high_perch/dry). Starting
## roster (data/staffers.json): Marlon's kitchen skill (3) clears
## stations.kitchen.dinner_min_skill (3); Shelly's (2) doesn't. Clock phase
## boundaries (autoload/clock.gd): EVENING starts at tick 161.

const EVENING_START_TICK := 161
const MARLON_DINNER_TICKS := 22 # balance.json's dinner_ticks_by_skill, skill 3


func _seat(party_id: int, room_type_id: String, instance_id: int, needs: Array, dinner_addon: bool = false) -> void:
	Sim.pending_arrivals.append(make_party(party_id, needs, 1))
	Sim.seat_party(party_id, room_type_id, instance_id, dinner_addon)


## Evening also spawns 1-3 RNG-drawn true Walk-in Diners (data/balance.json's
## dining.walkin_count_min/max) alongside a room guest's add-on. Tests that
## need to isolate the add-on's own serve/expiry timing strip those true
## Walk-ins (guest_id -1) right after Evening populates the queue, so a
## Kitchen Staffer's single-job-at-a-time throughput (or an unstaffed
## Kitchen's shared expiry) isn't at the mercy of how many Walk-ins the RNG
## happened to draw that day.
func _strip_true_walkins() -> void:
	for entry in Sim.walkin_queue.duplicate():
		if int(entry.get("guest_id", -1)) == -1:
			Sim.walkin_queue.erase(entry)


## --- Opting in at seating time ---

func test_seating_with_dinner_addon_flags_the_guest_and_the_room_card() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"], true)

	var room := GameState.room_instance("cozy_nook", 0)
	assert_true(room["occupant_dinner_addon"], "the Room card should reflect the opted-in add-on")
	var gid: int = room["occupant"]
	assert_true(Sim.guests[gid]["dinner_addon"], "the guest record should carry the opt-in too")


func test_seating_without_dinner_addon_leaves_the_room_card_unflagged() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])

	var room := GameState.room_instance("cozy_nook", 0)
	assert_false(room["occupant_dinner_addon"])


## --- Joining the Evening dinner queue ---

func test_evening_queues_an_opted_in_room_guests_addon() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"], true)
	var gid: int = GameState.room_instance("cozy_nook", 0)["occupant"]

	Clock.force_advance_ticks(EVENING_START_TICK)

	var entry := _find_walkin_entry_for_guest(gid)
	assert_false(entry.is_empty(), "the room guest's dinner add-on should join walkin_queue at Evening")
	assert_true(entry.has("patience"), "the add-on entry carries its own Patience, same as a true Walk-in Diner")


func test_evening_does_not_queue_a_room_guest_without_the_addon() -> void:
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"])
	var gid: int = GameState.room_instance("cozy_nook", 0)["occupant"]

	Clock.force_advance_ticks(EVENING_START_TICK)

	assert_true(_find_walkin_entry_for_guest(gid).is_empty(), "a guest who never opted in shouldn't appear in the dinner queue")


## --- Kitchen-skill gating matches Walk-in Diners (ticket 10) ---

func test_dinner_min_skill_gates_serving_the_addon_same_as_a_walkin() -> void:
	var shelly_skill := int(GameState.staffers["shelly"]["skills"]["kitchen"])
	assert_true(shelly_skill < 3, "test assumes Shelly sits below stations.kitchen.dinner_min_skill")
	Sim.assign_staffer("shelly", "kitchen")
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"], true)
	var gid: int = GameState.room_instance("cozy_nook", 0)["occupant"]

	Clock.force_advance_ticks(EVENING_START_TICK + 20) # comfortably past a would-be breakfast/dinner tick count

	assert_false(_find_walkin_entry_for_guest(gid).is_empty(), "a Staffer below the dinner threshold should never claim the add-on")


## --- Served outcome feeds Reputation/Hearts and resolves the indicator (ticket 11) ---

func test_served_addon_feeds_hearts_and_reputation_and_clears_the_room_card() -> void:
	Sim.assign_staffer("marlon", "kitchen")
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"], true)
	var gid: int = GameState.room_instance("cozy_nook", 0)["occupant"]

	watch_signals(EventBus)
	Clock.force_advance_ticks(EVENING_START_TICK)
	_strip_true_walkins() # isolate the add-on's own serve timing from the RNG-drawn Walk-in count
	# Baselines captured only after settling into Evening: Day 1's own
	# (unrelated) real arrivals have already resolved their Room-booking
	# walk-aways by this point, same precedent as test_dining_reputation.gd.
	var reputation_before := GameState.reputation
	var hearts_before := GameState.hearts
	Clock.force_advance_ticks(MARLON_DINNER_TICKS + 5)

	assert_true(_find_walkin_entry_for_guest(gid).is_empty(), "Marlon should have served the add-on")
	assert_signal_emit_count(EventBus, "dining_guest_served", 1)

	var room := GameState.room_instance("cozy_nook", 0)
	assert_false(room["occupant_dinner_addon"], "a resolved add-on should stop showing on the Room card")
	assert_false(Sim.guests[gid]["dinner_addon"], "the guest record's flag should clear too")
	assert_ne(GameState.hearts, hearts_before, "a served add-on should move Hearts, same as a good Checkout/Walk-in")
	assert_ne(GameState.reputation, reputation_before)


## --- Unserved outcome costs Reputation and resolves the indicator (ticket 11) ---

func test_unserved_addon_costs_reputation_and_clears_the_room_card() -> void:
	# Kitchen left unstaffed -- the add-on can never be served, only expire.
	_seat(1, "cozy_nook", 0, ["warm", "dry", "quiet"], true)
	var gid: int = GameState.room_instance("cozy_nook", 0)["occupant"]

	watch_signals(EventBus)
	Clock.force_advance_ticks(EVENING_START_TICK)
	_strip_true_walkins() # isolate the add-on's own expiry from the RNG-drawn Walk-in count
	# Baseline captured only after settling into Evening -- see the served-
	# addon test's comment above for why.
	var reputation_before := GameState.reputation
	# Comfortably past the Evening-configured Patience window at the
	# unstaffed-Kitchen multiplier.
	var patience_ticks := int(GameState.balance["dining"]["walkin_patience"]["start"]) + 10
	Clock.force_advance_ticks(patience_ticks)

	assert_true(_find_walkin_entry_for_guest(gid).is_empty(), "the unserved add-on should walk away once Patience expires")
	assert_signal_emit_count(EventBus, "dining_guest_walked_away", 1)
	assert_eq(GameState.reputation, reputation_before + int(GameState.balance["review"]["reputation_delta_walkaway"]))

	var room := GameState.room_instance("cozy_nook", 0)
	assert_false(room["occupant_dinner_addon"], "a walked-away add-on should stop showing on the Room card")
	assert_false(Sim.guests[gid]["dinner_addon"])


func _find_walkin_entry_for_guest(gid: int) -> Dictionary:
	for entry in Sim.walkin_queue:
		if int(entry.get("guest_id", -1)) == gid:
			return entry
	return {}
