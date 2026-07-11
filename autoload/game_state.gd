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
var _starting_hotel_template: Array = []

# Mutable hotel instance state: Array of {slot, room_type_id, occupant (guest id or null)}.
var hotel_rooms: Array = []

# Set of built amenity ids (e.g. "pool"). Empty until Chunk 2's Build menu
# exists; wired up now so Satisfaction's amenity bonus has something to read.
var hotel_amenities: Dictionary = {}


func _ready() -> void:
	_load_data()
	reset_to_starting_conditions()
	EventBus.day_advanced.connect(_on_day_advanced)


func _load_data() -> void:
	var data := DataLoader.load_all()
	tags = data["tags"]
	species = data["species"]
	rooms = data["rooms"]
	traits = data["traits"]
	seasons = data["seasons"]
	balance = data["balance"]
	_starting_hotel_template = data["starting_hotel"]
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


func _build_starting_hotel() -> void:
	hotel_rooms.clear()
	for entry in _starting_hotel_template:
		hotel_rooms.append({
			"slot": entry["slot"],
			"room_type_id": entry["room_type_id"],
			"occupant": null,
		})


func _on_day_advanced(new_day: int) -> void:
	day = new_day
