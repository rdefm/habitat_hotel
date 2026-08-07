class_name Satisfaction
extends RefCounted

## Tag-matching satisfaction scoring plus the review/Hearts thresholds
## derived from it. Computed once, at match time, as a pure function of the
## guest's needs/likes/amenity prefs, the assigned room's tags, the stay
## length, and which amenities the hotel currently has -- all of which are
## already fixed by the moment a guest is seated, so there is no need to
## mutate it day-by-day during the stay.

static func compute(arrival: Dictionary, room_type: Dictionary, hotel_amenities: Dictionary, balance: Dictionary) -> float:
	var s: Dictionary = balance["satisfaction"]
	var room_tags: Array = room_type["tags"]

	var missing := 0
	for need in arrival["needs"]:
		if not room_tags.has(need):
			missing += 1

	var likes_met := 0
	for like in arrival["likes"]:
		if room_tags.has(like):
			likes_met += 1

	var score: float = float(s["base"])
	score -= missing * float(s["missing_need_penalty"])
	score += likes_met * float(s["like_bonus"])
	score += minf(float(arrival["nights_total"]) * float(s["care_per_night"]), float(s["care_cap"]))

	for pref in arrival["amenity_prefs"]:
		if hotel_amenities.has(pref):
			score += float(s["amenity_bonus"])
			break

	score += float(room_type.get("satisfaction_bonus", 0))

	return clampf(score, float(s["min"]), float(s["max"]))


## A served dining guest's (Walk-in Diner or room guest's dinner add-on,
## ticket 11/ADR-0003) Satisfaction-like score -- same shape of contract as
## compute() above (clamped to the same satisfaction.min/max, fed through
## the same review_for()/hearts_for()/reputation_delta_for_review() below),
## but scored from dining-specific inputs instead of a Room match: whether
## the guest's Species matches today's Daily Special, and the serving
## Staffer's Kitchen skill (the same skill that already determines service
## speed via stations.kitchen.*_ticks_by_skill -- faster service reads here
## as a better meal).
static func compute_dining(matches_daily_special: bool, kitchen_skill: int, balance: Dictionary) -> float:
	var s: Dictionary = balance["satisfaction"]
	var d: Dictionary = balance["dining"]["satisfaction"]

	var score: float = float(d["base"])
	if matches_daily_special:
		score += float(d["special_match_bonus"])
	score += float(kitchen_skill) * float(d["skill_bonus_per_level"])

	return clampf(score, float(s["min"]), float(s["max"]))


static func review_for(score: float, balance: Dictionary) -> String:
	var r: Dictionary = balance["review"]
	if score >= float(r["positive_threshold"]):
		return "positive"
	if score < float(r["negative_threshold"]):
		return "negative"
	return "neutral"


static func hearts_for(score: float, balance: Dictionary) -> int:
	var h: Dictionary = balance["hearts"]
	if score < float(h["threshold"]):
		return 0
	var over: float = score - float(h["threshold"])
	var steps: int = int(over / float(h["step"])) + 1
	return mini(steps, int(h["max"]))


static func reputation_delta_for_review(review: String, balance: Dictionary) -> int:
	var r: Dictionary = balance["review"]
	match review:
		"positive":
			return int(r["reputation_delta_positive"])
		"negative":
			return int(r["reputation_delta_negative"])
		_:
			return 0
