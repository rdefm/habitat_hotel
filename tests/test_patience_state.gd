extends GutTest

## Characterizes sim/patience_state.gd's tier() -- the pure calm/impatient/huffy
## classification Reception uses (ticket 05) to give the player fair warning
## before a pending Party's Patience hits zero and it walks away. Thresholds
## are data/balance.json's patience.impatient_at/huffy_at, both Patience
## VALUES the countdown crosses on its way from patience.start to 0, not
## durations.

const PatienceState = preload("res://sim/patience_state.gd")

const BALANCE := {
	"patience": {"start": 80, "decay_per_tick": 1, "impatient_at": 40, "huffy_at": 15},
}


func test_tier_is_calm_above_the_impatient_threshold() -> void:
	assert_eq(PatienceState.tier(80.0, BALANCE), "calm")
	assert_eq(PatienceState.tier(41.0, BALANCE), "calm")


func test_tier_is_impatient_at_and_below_the_impatient_threshold() -> void:
	assert_eq(PatienceState.tier(40.0, BALANCE), "impatient")
	assert_eq(PatienceState.tier(16.0, BALANCE), "impatient")


func test_tier_is_huffy_at_and_below_the_huffy_threshold() -> void:
	assert_eq(PatienceState.tier(15.0, BALANCE), "huffy")
	assert_eq(PatienceState.tier(0.0, BALANCE), "huffy")
