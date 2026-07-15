extends Node

## Single source of randomness for the sim. Per the determinism rule, all
## sim-side random draws must go through this service (never
## Godot's global randi()/randf()), so a run is fully reproducible from a seed.

const DEFAULT_SEED := 1337

var seed_value: int = DEFAULT_SEED

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = seed_value


func reset(new_seed: int = DEFAULT_SEED) -> void:
	seed_value = new_seed
	_rng.seed = new_seed


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randf() -> float:
	return _rng.randf()
