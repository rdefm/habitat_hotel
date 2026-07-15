class_name SimState
extends RefCounted

## The entire mutable game state. Plain data (Dictionaries/Arrays/primitives)
## so it serializes trivially -- see sim_save.gd. sim/ systems take a
## SimState instance plus a SimContent (read-only tables) and mutate it in
## place; game/ never touches this directly.

const SCHEMA_VERSION := 1

var schema_version: int = SCHEMA_VERSION
var rng_seed: int = 0
var rng_state: int = 0

var day: int = 1
var season: String = "summer"
var phase: String = "morning"        # "morning" | "afternoon" | "evening" | "night"
var phase_elapsed: float = 0.0       # sim-seconds elapsed in current phase
var tick_accumulator: float = 0.0    # leftover sim-seconds not yet consumed as a whole tick

var base_speed: float = 1.0          # 1.0 or 2.0, set via set_speed command
var hard_paused: bool = false
var soft_slow: bool = false          # true while a queued guest is held/selected

var cash: int = 0

# Array of room dicts: {plot_id, room_type, state, stay_id}
# state in {"empty", "vacant", "occupied", "dirty", "cleaning"}
# room_type is "" for an empty (unbuilt) plot. stay_id is -1 when not occupied.
var rooms: Array = []

var housekeeping_order: Array = []   # plot_ids waiting to be cleaned, FIFO
var cleaning_plot_id: int = -1
var cleaning_progress: float = 0.0   # sim-seconds elapsed on the current clean

# Array of queue entry dicts: {party_id, species_id, party_count,
# original_party_count, nights_total, patience_remaining, patience_max,
# rooms_used, arrival_day}
var queue: Array = []

# stay_id (String key) -> stay dict: {stay_id, plot_id, species_id,
# party_count, nights_total, day_seated, day_checkout, satisfaction,
# original_party_id, needs_missing, likes_met}
var stays: Dictionary = {}

var next_party_id: int = 1
var next_stay_id: int = 1

# {"afternoon": [{species_id, party_count, nights_total, offset_sim_seconds,
#   spawned}], "morning_popin": null|dict, "evening_popin": null|dict}
var today_schedule: Dictionary = {"afternoon": [], "morning_popin": null, "evening_popin": null}
var tomorrow_schedule: Dictionary = {}
var has_tomorrow_schedule: bool = false

var turned_away_log: Array = []      # {day, species_id, party_count, reason}
var day_metrics: Dictionary = {}     # accumulating counters for the day in progress
var last_day_summary: Dictionary = {}
