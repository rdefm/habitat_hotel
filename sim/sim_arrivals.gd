class_name SimArrivals
extends RefCounted

const SimContent = preload("res://sim/sim_content.gd")
const SimRng = preload("res://sim/sim_rng.gd")

## Nightly generation of the next day's arrival schedule: N afternoon
## parties (species/size/stay weighted by data, spread across the first
## slice of the afternoon) plus independent morning/evening pop-in rolls.
## Pure function of (content, day, rng) -- the caller stores the result and
## drains it into the queue tick by tick as offsets are reached.

static func generate_schedule(content: SimContent, day: int, rng: SimRng) -> Dictionary:
	var balance: Dictionary = content.balance
	var ramp: Array = balance.get("arrivals_ramp_by_day", [[1, 2, 3]])
	var min_n := int(balance.get("arrivals_per_day_min", 2))
	var max_n := int(balance.get("arrivals_per_day_max", 5))
	for tier_entry in ramp:
		if day >= int(tier_entry[0]):
			min_n = int(tier_entry[1])
			max_n = int(tier_entry[2])
	var n := rng.randi_range(min_n, max_n)

	var lengths: Dictionary = balance.get("phase_lengths_sim_seconds", {})
	var afternoon_length := float(lengths.get("afternoon", 50.0))
	var spread := float(balance.get("arrival_spread_fraction", 0.7))

	var afternoon: Array = []
	for i in range(n):
		var party := _generate_party(content, rng)
		party["offset_sim_seconds"] = rng.randf_range(0.0, afternoon_length * spread)
		party["spawned"] = false
		afternoon.append(party)
	afternoon.sort_custom(func(a, b): return a["offset_sim_seconds"] < b["offset_sim_seconds"])

	var morning_popin = null
	if rng.randf() < float(balance.get("popin_chance_morning", 0.0)):
		morning_popin = _generate_party(content, rng)
		morning_popin["offset_sim_seconds"] = rng.randf_range(0.0, float(lengths.get("morning", 30.0)))
		morning_popin["spawned"] = false

	var evening_popin = null
	if rng.randf() < float(balance.get("popin_chance_evening", 0.0)):
		evening_popin = _generate_party(content, rng)
		evening_popin["offset_sim_seconds"] = rng.randf_range(0.0, float(lengths.get("evening", 20.0)))
		evening_popin["spawned"] = false

	return {"afternoon": afternoon, "morning_popin": morning_popin, "evening_popin": evening_popin}

static func _generate_party(content: SimContent, rng: SimRng) -> Dictionary:
	var max_tier := int(content.balance.get("max_guest_tier", 99))
	var species_ids := content.species_ids_at_or_below_tier(max_tier)
	var weights: Dictionary = {}
	for sid in species_ids:
		weights[sid] = float(content.species[sid].get("weight", 1.0))
	var species_id: String = rng.weighted_pick(weights)
	var species: Dictionary = content.species[species_id]
	return {
		"species_id": species_id,
		"party_count": rng.randi_range(int(species["party_min"]), int(species["party_max"])),
		"nights_total": rng.randi_range(int(species["stay_min"]), int(species["stay_max"])),
	}
