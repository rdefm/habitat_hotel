extends GutTest

## Characterizes sim/patience_state.gd's tier() -- the pure calm/impatient/huffy
## classification Reception (ticket 05) and the Terrace view's dinner queue
## (ticket 14) both use to give the player fair warning before a Patience
## value hits zero and its owner walks away. Thresholds come from whatever
## patience config dict the caller passes (data/balance.json's "patience"
## block for Reception, "dining.walkin_patience" for the dinner queue) --
## impatient_at/huffy_at are both Patience VALUES the countdown crosses on
## its way from that config's own "start" to 0, not durations.

const PatienceState = preload("res://sim/patience_state.gd")

const PATIENCE_CFG := {"start": 80, "decay_per_tick": 1, "impatient_at": 40, "huffy_at": 15}


func test_tier_is_calm_above_the_impatient_threshold() -> void:
	assert_eq(PatienceState.tier(80.0, PATIENCE_CFG), "calm")
	assert_eq(PatienceState.tier(41.0, PATIENCE_CFG), "calm")


func test_tier_is_impatient_at_and_below_the_impatient_threshold() -> void:
	assert_eq(PatienceState.tier(40.0, PATIENCE_CFG), "impatient")
	assert_eq(PatienceState.tier(16.0, PATIENCE_CFG), "impatient")


func test_tier_is_huffy_at_and_below_the_huffy_threshold() -> void:
	assert_eq(PatienceState.tier(15.0, PATIENCE_CFG), "huffy")
	assert_eq(PatienceState.tier(0.0, PATIENCE_CFG), "huffy")
