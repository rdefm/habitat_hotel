class_name SimClock
extends RefCounted

const SimState = preload("res://sim/sim_state.gd")

## Pure phase/day timekeeping. Morning/Afternoon/Evening advance
## automatically once their sim-second length elapses; Night has no
## duration -- it halts until an explicit {type="next_day"} command
## (handled by sim_game.gd, which also owns checkout/generation
## orchestration). This file only knows about time, not what happens
## during each phase.

const PHASE_ORDER: Array[String] = ["morning", "afternoon", "evening", "night"]

static func effective_speed(state: SimState, balance: Dictionary) -> float:
	if state.hard_paused:
		return 0.0
	if state.soft_slow:
		return float(balance.get("speed_soft_slow", 0.3))
	return state.base_speed

## Advances the phase timer by one fixed sim-second tick. Returns true if
## the phase just changed (the caller should react: sim_game.gd hooks
## checkout/cleaning/day-summary logic off phase transitions).
static func tick(state: SimState, balance: Dictionary, tick_duration: float) -> bool:
	if state.phase == "night":
		return false
	state.phase_elapsed += tick_duration
	var lengths: Dictionary = balance.get("phase_lengths_sim_seconds", {})
	var current_length := float(lengths.get(state.phase, 0.0))
	if state.phase_elapsed < current_length:
		return false
	var overflow := state.phase_elapsed - current_length
	var idx := PHASE_ORDER.find(state.phase)
	var next_phase: String = PHASE_ORDER[idx + 1] if idx + 1 < PHASE_ORDER.size() else "night"
	state.phase = next_phase
	state.phase_elapsed = 0.0 if next_phase == "night" else overflow
	return true
