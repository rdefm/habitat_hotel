extends Node

## Authoritative economy/session state (section 3.7) plus the loaded data
## registries. Data loading happens once here at boot; reset_to_starting_conditions()
## re-derives the mutable session state (cash, hotel_rooms, ...) from that
## loaded data, used both at boot and by the headless batch runner.

const DataLoader = preload("res://sim/data_loader.gd")

const STARTING_CASH := 5000
const STARTING_HEARTS := 0
const STARTING_REPUTATION := 50
const STARTING_STARS := 1
const STARTING_SEASON := "summer"
const DEFAULT_MATCHER_POLICY := "fill_vacancies" # or "strict_match"

var cash: int = STARTING_CASH
var hearts: int = STARTING_HEARTS
var reputation: int = STARTING_REPUTATION
var stars: int = STARTING_STARS
var day: int = 1
var season: String = STARTING_SEASON
var matcher_policy: String = DEFAULT_MATCHER_POLICY

# Loaded once from data/*.json, treated as read-only content.
var tags: Dictionary = {}
var species: Dictionary = {}
var rooms: Dictionary = {}
var traits: Dictionary = {}
var seasons: Dictionary = {}
var balance: Dictionary = {}
var names: Dictionary = {}
var slot_layout: Array = []
var _starting_hotel_template: Array = []

# Mutable hotel instance state: Array of {slot, room_type_id, occupant (guest id or null)}.
# Only ever contains BUILT rooms -- Sim/Matcher never need to know about
# locked or unlocked-but-empty slots, that's purely a Build-menu concern.
var hotel_rooms: Array = []

# Set of built amenity ids (e.g. "pool"). Empty until amenities can be built;
# wired up now so Satisfaction's amenity bonus has something to read.
var hotel_amenities: Dictionary = {}

# room_type_id -> current price multiplier applied to that type's base_rate.
var price_multipliers: Dictionary = {}

# Persistent record for the Reports/Reviews menus -- survives a menu being
# closed and reopened. Cleared on reset_to_starting_conditions().
var day_history: Array = []
var review_history: Array = []

# Tomorrow's forecast arrivals (generated a phase early by Sim so the player
# has a real window to plan a build before they resolve). upcoming_arrivals_day
# is the day this forecast is FOR, not the day it was generated.
var upcoming_arrivals: Array = []
var upcoming_arrivals_day: int = 0


func _ready() -> void:
	_load_data()
	reset_to_starting_conditions()
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.day_summary.connect(_on_day_summary)
	EventBus.review_posted.connect(_on_review_posted)
	EventBus.forecast_ready.connect(_on_forecast_ready)


func _load_data() -> void:
	var data := DataLoader.load_all()
	tags = data["tags"]
	species = data["species"]
	rooms = data["rooms"]
	traits = data["traits"]
	seasons = data["seasons"]
	balance = data["balance"]
	_starting_hotel_template = data["starting_hotel"]
	slot_layout = data["slot_layout"]
	names = data["names"]
	EventBus.data_loaded.emit()


## Restores cash/hearts/reputation/stars/day/season/policy and the hotel's
## room layout to their day-1 starting values. Does not touch loaded content
## (species/rooms/tags/etc.) or the Clock -- callers that need a fully clean
## run (e.g. the batch runner) should also call Clock.reset() and Rng.reset().
func reset_to_starting_conditions(policy: String = DEFAULT_MATCHER_POLICY) -> void:
	cash = STARTING_CASH
	hearts = STARTING_HEARTS
	reputation = STARTING_REPUTATION
	stars = STARTING_STARS
	day = 1
	season = STARTING_SEASON
	matcher_policy = policy
	hotel_amenities.clear()
	_build_starting_hotel()
	_reset_price_multipliers()
	day_history.clear()
	review_history.clear()
	upcoming_arrivals.clear()
	upcoming_arrivals_day = 0


func _on_day_summary(summary: Dictionary) -> void:
	day_history.append(summary)


func _on_review_posted(review: Dictionary) -> void:
	review_history.append(review)


func _on_forecast_ready(for_day: int, arrivals: Array) -> void:
	upcoming_arrivals_day = for_day
	upcoming_arrivals = arrivals


func _build_starting_hotel() -> void:
	hotel_rooms.clear()
	for entry in _starting_hotel_template:
		hotel_rooms.append({
			"slot": entry["slot"],
			"room_type_id": entry["room_type_id"],
			"occupant": null,
			"occupant_name": null,
			"occupant_species_id": null,
			"occupant_mismatch": false,
			"upgrades": [],
		})


func _reset_price_multipliers() -> void:
	price_multipliers.clear()
	var default_mult: float = float(balance.get("pricing", {}).get("default_multiplier", 1.0))
	for room_type_id in rooms.keys():
		price_multipliers[room_type_id] = default_mult


func _on_day_advanced(new_day: int) -> void:
	day = new_day


## --- Slot/build queries, used by the Build menu ---

func is_slot_unlocked(slot_index: int) -> bool:
	for entry in slot_layout:
		if int(entry["slot"]) == slot_index:
			return stars >= int(entry["unlock"]["star"])
	return false


func room_at_slot(slot_index: int) -> Dictionary:
	for room in hotel_rooms:
		if int(room["slot"]) == slot_index:
			return room
	return {}


func can_build_room_type(room_type_id: String) -> bool:
	if not rooms.has(room_type_id):
		return false
	return stars >= int(rooms[room_type_id]["unlock"]["star"])


## Attempts to build room_type_id into slot_index. Returns true on success;
## false (with no side effects) if the slot is locked, already occupied, the
## room type isn't unlocked yet, or cash is insufficient.
func build_room(slot_index: int, room_type_id: String) -> bool:
	if not is_slot_unlocked(slot_index):
		return false
	if not room_at_slot(slot_index).is_empty():
		return false
	if not can_build_room_type(room_type_id):
		return false
	var cost := int(rooms[room_type_id]["build_cost"])
	if cash < cost:
		return false
	cash -= cost
	hotel_rooms.append({"slot": slot_index, "room_type_id": room_type_id, "occupant": null, "occupant_name": null, "occupant_species_id": null, "occupant_mismatch": false, "upgrades": []})
	return true


## --- Upgrade queries, used by the Upgrade menu ---

## Merges a room instance's base type stats with the effects of every
## upgrade it has purchased. This is what Matcher/Satisfaction/Sim's upkeep
## calc should always read instead of GameState.rooms[...] directly, since
## two instances of the same room type can have different upgrades.
func effective_room_stats(room_instance: Dictionary) -> Dictionary:
	var base: Dictionary = rooms[room_instance["room_type_id"]]
	var stats: Dictionary = base.duplicate(true)
	stats["satisfaction_bonus"] = 0

	for upgrade_id in room_instance.get("upgrades", []):
		var upgrade := _find_upgrade(base, upgrade_id)
		if upgrade.is_empty():
			continue
		if upgrade.has("adds_tag") and not stats["tags"].has(upgrade["adds_tag"]):
			stats["tags"].append(upgrade["adds_tag"])
		if upgrade.has("upkeep_delta"):
			stats["upkeep_per_day"] = maxi(0, int(stats["upkeep_per_day"]) + int(upgrade["upkeep_delta"]))
		if upgrade.has("capacity_delta"):
			stats["capacity"] = maxi(1, int(stats["capacity"]) + int(upgrade["capacity_delta"]))
		if upgrade.has("satisfaction_bonus"):
			stats["satisfaction_bonus"] = float(stats["satisfaction_bonus"]) + float(upgrade["satisfaction_bonus"])

	return stats


## Upgrades in room_instance's type catalog that haven't been purchased yet.
func available_upgrades_for(room_instance: Dictionary) -> Array:
	var base: Dictionary = rooms[room_instance["room_type_id"]]
	var purchased: Array = room_instance.get("upgrades", [])
	var out: Array = []
	for upgrade in base.get("upgrades", []):
		if not purchased.has(upgrade["id"]):
			out.append(upgrade)
	return out


func _find_upgrade(room_type: Dictionary, upgrade_id: String) -> Dictionary:
	for upgrade in room_type.get("upgrades", []):
		if upgrade["id"] == upgrade_id:
			return upgrade
	return {}


## Attempts to buy upgrade_id for the room built at slot_index. Returns true
## on success; false (no side effects) if the slot has no room, the upgrade
## doesn't exist/is already purchased, or cash+Hearts are insufficient.
func purchase_upgrade(slot_index: int, upgrade_id: String) -> bool:
	var room := room_at_slot(slot_index)
	if room.is_empty():
		return false
	var base: Dictionary = rooms[room["room_type_id"]]
	var upgrade := _find_upgrade(base, upgrade_id)
	if upgrade.is_empty():
		return false
	if room["upgrades"].has(upgrade_id):
		return false
	var cost_cash := int(upgrade["cost_cash"])
	var cost_hearts := int(upgrade["cost_hearts"])
	if cash < cost_cash or hearts < cost_hearts:
		return false
	cash -= cost_cash
	hearts -= cost_hearts
	room["upgrades"].append(upgrade_id)
	return true


## --- Pricing queries, used by the Prices menu ---

func price_multiplier_for(room_type_id: String) -> float:
	return float(price_multipliers.get(room_type_id, float(balance.get("pricing", {}).get("default_multiplier", 1.0))))


## Sets room_type_id's price multiplier, clamped to balance.json's configured
## min/max. Returns the clamped value actually applied.
func set_price_multiplier(room_type_id: String, value: float) -> float:
	var pricing: Dictionary = balance.get("pricing", {})
	var clamped := clampf(value, float(pricing.get("min_multiplier", 0.5)), float(pricing.get("max_multiplier", 2.0)))
	price_multipliers[room_type_id] = clamped
	return clamped
