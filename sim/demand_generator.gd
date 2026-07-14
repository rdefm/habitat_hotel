class_name DemandGenerator
extends RefCounted

## Produces each day's arriving guest parties. Star level gates which
## species are eligible; reputation scales the daily count; season tag
## weights bias which eligible species show up (neutral until real season
## data lands in Chunk 5). Pure function of its inputs plus the shared Rng
## service -- no state of its own.

static func generate(game_state: Node, rng: Node) -> Array:
	var eligible: Array = []
	for id in game_state.species.keys():
		var s: Dictionary = game_state.species[id]
		if s["tier"] <= game_state.stars:
			eligible.append(s)
	if eligible.is_empty():
		return []

	var season_data: Dictionary = game_state.seasons.get(game_state.season, {})
	var tag_weights: Dictionary = season_data.get("tag_weights", {})

	var demand: Dictionary = game_state.balance["demand"]
	var base_count: int = rng.randi_range(int(demand["base_min"]), int(demand["base_max"]))
	var rep_fraction: float = clampf(float(game_state.reputation) / 100.0, 0.0, 1.0)
	var rep_factor: float = lerpf(float(demand["reputation_weight_min"]), float(demand["reputation_weight_max"]), rep_fraction)
	var count: int = maxi(0, int(round(base_count * rep_factor)))

	var names: Dictionary = game_state.names

	var arrivals: Array = []
	for i in range(count):
		var s: Dictionary = _weighted_pick(eligible, tag_weights, rng)
		var party_size: int = rng.randi_range(int(s["party_size"][0]), int(s["party_size"][1]))
		var nights: int = rng.randi_range(int(s["base_stay_days"][0]), int(s["base_stay_days"][1]))
		arrivals.append({
			"species_id": s["id"],
			"needs": s["needs"],
			"likes": s["likes"],
			"amenity_prefs": s["amenity_prefs"],
			"budget": s["budget"],
			"party_size": party_size,
			"nights_total": nights,
			"name": _pick_name(s["id"], names, rng),
		})
	return arrivals


## Equal chance of drawing from the general pool or this species' own pool;
## falls back to general if the species has no pool (or it's empty).
static func _pick_name(species_id: String, names: Dictionary, rng: Node) -> String:
	var general: Array = names.get("general", [])
	var species_pool: Array = names.get("species", {}).get(species_id, [])

	var pool := general
	if not species_pool.is_empty() and rng.randf() < 0.5:
		pool = species_pool
	if pool.is_empty():
		return "Guest"
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _weighted_pick(list: Array, tag_weights: Dictionary, rng: Node) -> Dictionary:
	var weights: Array = []
	var total := 0.0
	for s in list:
		var w := 1.0
		for need in s["needs"]:
			w *= float(tag_weights.get(need, 1.0))
		weights.append(w)
		total += w
	if total <= 0.0:
		return list[list.size() - 1]
	var r: float = rng.randf() * total
	var acc := 0.0
	for i in range(list.size()):
		acc += weights[i]
		if r <= acc:
			return list[i]
	return list[list.size() - 1]
