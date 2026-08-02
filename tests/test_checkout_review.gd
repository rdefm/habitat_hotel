extends "res://tests/helpers/sim_test_base.gd"

## Characterizes a checkout producing a review via real day/night cycles
## (Clock.force_advance_day(), same call the headless batch runner uses)
## from a freshly reset GameState/Sim. Values below are the deterministic
## output of Rng's default seed (1337) -- see the note in
## test_day_night_cycle.gd about re-deriving them if demand/matching/economy
## logic legitimately changes.
##
## Quirk worth knowing if these ever need re-deriving: force_advance_day()
## runs exactly one day's 240 ticks, and the tick that rolls day N into day
## N+1 immediately fires day N+1's Morning phase (checkout processing) in
## the same call, one call before that day's own day_summary is emitted. So
## the 3 checkouts that show up in day_history's day-3 entry are actually
## posted (EventBus.review_posted, GameState.review_history) during the 2nd
## force_advance_day() call, not the 3rd.

func test_two_day_cycle_posts_checkout_reviews_before_that_days_summary_exists() -> void:
	watch_signals(EventBus)

	Clock.force_advance_day()
	Clock.force_advance_day()

	assert_signal_emit_count(EventBus, "review_posted", 3)
	assert_signal_emit_count(EventBus, "guest_checked_out", 3)
	assert_signal_emit_count(EventBus, "room_marked_dirty", 3)

	assert_eq(GameState.review_history.size(), 3)
	var reviews: Array = GameState.review_history

	assert_eq(reviews[0]["guest_name"], "Squawk Norris")
	assert_eq(reviews[0]["species_id"], "pigeon")
	assert_eq(reviews[0]["review"], "neutral")
	assert_eq(reviews[0]["satisfaction"], 66.0)
	assert_eq(reviews[0]["revenue"], 70)
	assert_eq(reviews[0]["day"], 3)

	assert_eq(reviews[1]["guest_name"], "Cappy Baraiah")
	assert_eq(reviews[1]["species_id"], "capybara")
	assert_eq(reviews[1]["review"], "neutral")
	assert_eq(reviews[1]["satisfaction"], 66.0)
	assert_eq(reviews[1]["revenue"], 120)

	assert_eq(reviews[2]["guest_name"], "Feather Locklear")
	assert_eq(reviews[2]["species_id"], "pigeon")
	assert_eq(reviews[2]["review"], "neutral")
	assert_eq(reviews[2]["satisfaction"], 41.0)
	assert_eq(reviews[2]["revenue"], 120)


func test_checkout_leaves_its_room_dirty_and_vacant_until_the_next_evening_cleans_it() -> void:
	Clock.force_advance_day()
	Clock.force_advance_day()

	var is_occupied := func(r): return r["occupant"] != null
	var is_dirty := func(r): return r["needs_cleaning"]
	assert_eq(count_rooms(is_occupied), 1, "3 of the 4 starting rooms were freed by checkout")
	assert_eq(count_rooms(is_dirty), 3, "freed rooms start dirty -- Evening hasn't cleaned them yet")

	watch_signals(EventBus)
	Clock.force_advance_day()

	assert_signal_emit_count(EventBus, "room_cleaned", 3, "the next day's Evening phase should clean all 3 dirty rooms")
	assert_eq(count_rooms(is_dirty), 1, "only the newly-checked-out 4th room (processed by this call's own day-4 morning cascade) should still be dirty")


func test_neutral_review_awards_no_hearts_and_no_reputation_change() -> void:
	# All 3 of these checkouts score "neutral" (below the 70-satisfaction
	# Hearts threshold, above the 40-satisfaction negative-review floor), so
	# both Hearts and Reputation should be untouched by them.
	Clock.force_advance_day()
	Clock.force_advance_day()

	assert_eq(GameState.hearts, 0)
	assert_eq(GameState.reputation, 50, "no walk-away or negative review occurred in the first 2 calls to move it off the starting 50")
