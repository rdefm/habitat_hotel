class_name SimRng
extends RefCounted

## Thin wrapper around RandomNumberGenerator that exposes its internal
## state as a single serializable int, so save/load can reproduce the
## exact same future random sequence (determinism invariant, Part F test 1/2).

var _rng := RandomNumberGenerator.new()

func seed_with(seed_value: int) -> void:
	_rng.seed = seed_value

func get_seed() -> int:
	return _rng.seed

func get_state() -> int:
	return _rng.state

func set_state(state_value: int) -> void:
	_rng.state = state_value

func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)

func randf() -> float:
	return _rng.randf()

func randf_range(from: float, to: float) -> float:
	return _rng.randf_range(from, to)

## Weighted pick from {key: weight, ...}. Deterministic given RNG state.
func weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights.keys():
		total += float(weights[k])
	if total <= 0.0:
		return weights.keys()[0]
	var roll := randf_range(0.0, total)
	var acc := 0.0
	for k in weights.keys():
		acc += float(weights[k])
		if roll <= acc:
			return k
	return weights.keys()[-1]
