extends Node

## Tick/phase driver for the 60-second in-game day. Pure timekeeping: emits
## EventBus signals on tick/phase/day changes and holds no economy state.

const TICKS_PER_DAY := 240
const TICK_DURATION := 0.25 # seconds per tick at 1x speed (240 * 0.25 = 60s/day)

enum Phase { MORNING, MIDDAY, EVENING, NIGHT }

# First tick (1-indexed, within the 1..TICKS_PER_DAY range) of each phase.
const PHASE_START_TICKS := [
	[Phase.MORNING, 1],
	[Phase.MIDDAY, 61],
	[Phase.EVENING, 161],
	[Phase.NIGHT, 221],
]

var day: int = 1
var tick_in_day: int = 0
var current_phase: Phase = Phase.MORNING
var speed: float = 1.0
var paused: bool = false

var _elapsed: float = 0.0
var _announced_start: bool = false


func _process(delta: float) -> void:
	_ensure_started()
	if paused:
		return
	_elapsed += delta * speed
	while _elapsed >= TICK_DURATION:
		_elapsed -= TICK_DURATION
		_advance_tick()


## Emits the initial phase (Day 1 Morning) exactly once, the first time the
## clock actually starts running. Deferred like this (rather than emitted
## from _ready) so every listener -- autoloads and the main scene alike --
## is guaranteed to already be connected, regardless of autoload order.
func _ensure_started() -> void:
	if _announced_start:
		return
	_announced_start = true
	EventBus.phase_changed.emit(day, Phase.keys()[current_phase])


## Synchronously simulates exactly one full day's worth of ticks, ignoring
## real time and the paused flag. Used by the headless batch runner.
func force_advance_day() -> void:
	_ensure_started()
	for i in range(TICKS_PER_DAY):
		_advance_tick()


func _advance_tick() -> void:
	tick_in_day += 1
	EventBus.tick_advanced.emit(day, tick_in_day)

	var new_phase := _phase_for_tick(tick_in_day)
	if new_phase != current_phase:
		current_phase = new_phase
		EventBus.phase_changed.emit(day, Phase.keys()[current_phase])

	if tick_in_day >= TICKS_PER_DAY:
		tick_in_day = 0
		day += 1
		current_phase = Phase.MORNING
		EventBus.day_advanced.emit(day)
		EventBus.phase_changed.emit(day, Phase.keys()[current_phase])


func _phase_for_tick(tick: int) -> Phase:
	var result: Phase = Phase.MORNING
	for pair in PHASE_START_TICKS:
		if tick >= pair[1]:
			result = pair[0]
	return result


func set_paused(value: bool) -> void:
	if paused == value:
		return
	paused = value
	EventBus.clock_paused_changed.emit(paused)


func toggle_paused() -> void:
	set_paused(not paused)


## Player-facing speeds are 1x/2x per the design; debug/verification code may
## pass other multipliers directly.
func set_speed(value: float) -> void:
	speed = value
	EventBus.clock_speed_changed.emit(speed)


## Resets all clock-owned state back to Day 1, tick 0. Used by the batch
## runner so a batch simulates cleanly "from starting conditions."
func reset() -> void:
	day = 1
	tick_in_day = 0
	current_phase = Phase.MORNING
	speed = 1.0
	paused = false
	_elapsed = 0.0
	_announced_start = false
