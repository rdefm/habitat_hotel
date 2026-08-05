class_name PatienceState
extends RefCounted

## Pure classification of a pending Party's Patience value into the three
## display tiers Reception (ticket 05) uses to give the player fair warning
## before a Party's Patience hits zero and it walks away: calm -> impatient
## -> huffy. Thresholds are data/balance.json's patience.impatient_at/
## huffy_at -- both Patience VALUES the countdown crosses on its way down
## from patience.start to 0, not durations.

static func tier(patience: float, balance: Dictionary) -> String:
	var p: Dictionary = balance["patience"]
	if patience <= float(p["huffy_at"]):
		return "huffy"
	if patience <= float(p["impatient_at"]):
		return "impatient"
	return "calm"
