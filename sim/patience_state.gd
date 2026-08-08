class_name PatienceState
extends RefCounted

## Pure classification of a Patience value into the three display tiers
## calm -> impatient -> huffy: Reception (ticket 05) uses it for a pending
## Party's Patience, and the Terrace view (ticket 14) reuses it for the
## Evening walk-in dinner queue's Patience. Takes the specific patience
## config dict (e.g. data/balance.json's "patience" block, or
## "dining.walkin_patience") rather than the whole balance Dictionary, since
## the two queues decay against different start/threshold values --
## impatient_at/huffy_at are both Patience VALUES the countdown crosses on
## its way down from that config's own "start", not durations.

static func tier(patience: float, patience_cfg: Dictionary) -> String:
	if patience <= float(patience_cfg["huffy_at"]):
		return "huffy"
	if patience <= float(patience_cfg["impatient_at"]):
		return "impatient"
	return "calm"
