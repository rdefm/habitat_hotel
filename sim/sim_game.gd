class_name SimGame
extends RefCounted

const SimContent = preload("res://sim/sim_content.gd")
const SimState = preload("res://sim/sim_state.gd")
const SimEvents = preload("res://sim/sim_events.gd")
const SimRng = preload("res://sim/sim_rng.gd")
const SimRooms = preload("res://sim/sim_rooms.gd")
const SimEconomyStub = preload("res://sim/sim_economy_stub.gd")
const SimArrivals = preload("res://sim/sim_arrivals.gd")
const SimClock = preload("res://sim/sim_clock.gd")
const SimQueue = preload("res://sim/sim_queue.gd")
const SimMatching = preload("res://sim/sim_matching.gd")
const SimSave = preload("res://sim/sim_save.gd")

## Top-level sim: owns state, advances it, and is the only way in or out.
## Commands in: submit(command). Events out: drain_events(). Presentation
## may read get_state()/get_content() for display but must never mutate
## them -- all mutation happens inside sim/ systems called from here.

var content: SimContent
var state: SimState
var _events := SimEvents.new()
var _rng := SimRng.new()

func _init(data_dir: String = "res://data", seed_value: int = 1) -> void:
	content = SimContent.load_from_dir(data_dir)
	state = SimState.new()
	_rng.seed_with(seed_value)
	state.rng_seed = seed_value
	state.rng_state = _rng.get_state()

	SimRooms.init_starting_hotel(state, content)
	state.cash = int(content.balance.get("starting_cash", 0))
	_start_day_one()

func _start_day_one() -> void:
	SimEconomyStub.reset_day_metrics(state, state.day)
	state.today_schedule = SimArrivals.generate_schedule(content, state.day, _rng)
	state.rng_state = _rng.get_state()
	_events.emit("phase_changed", {"day": state.day, "phase": state.phase})

func get_state() -> SimState:
	return state

func get_content() -> SimContent:
	return content

func drain_events() -> Array[Dictionary]:
	return _events.drain()

## Real seconds elapsed since the last call. Internally scaled by the
## current sim speed (pause/1x/2x/soft-slow) and consumed as whole fixed
## sim-second ticks, so all sim logic is speed-agnostic (Part C).
func advance(delta_seconds: float) -> void:
	var tick_duration := 1.0 / float(content.balance.get("ticks_per_sim_second", 8))
	var speed := SimClock.effective_speed(state, content.balance)
	state.tick_accumulator += delta_seconds * speed
	while state.tick_accumulator >= tick_duration:
		state.tick_accumulator -= tick_duration
		_tick(tick_duration)

func _tick(tick_duration: float) -> void:
	var changed := SimClock.tick(state, content.balance, tick_duration)
	if changed:
		_on_phase_entered(state.phase)
	if state.phase == "night":
		return
	SimQueue.spawn_due_arrivals(state, content, _events)
	SimQueue.tick_patience(state, tick_duration, _events)
	SimRooms.tick_housekeeping(state, content, tick_duration, _events)

func _on_phase_entered(phase: String) -> void:
	_events.emit("phase_changed", {"day": state.day, "phase": phase})
	if phase == "night":
		state.last_day_summary = SimEconomyStub.build_day_summary(state)
		_events.emit("day_summary_ready", state.last_day_summary)
		state.tomorrow_schedule = SimArrivals.generate_schedule(content, state.day + 1, _rng)
		state.rng_state = _rng.get_state()
		state.has_tomorrow_schedule = true

## Validates and applies a command. Never trust the caller -- every command
## is checked before it can mutate state.
func submit(command: Dictionary) -> Dictionary:
	match command.get("type", ""):
		"seat_guest":
			return SimMatching.seat_guest(state, content, int(command.get("party_id", -1)), int(command.get("plot_id", -1)), _events)
		"build_room":
			return SimRooms.build_room(state, content, int(command.get("plot_id", -1)), String(command.get("room_type", "")), _events)
		"set_speed":
			var value := float(command.get("value", 1.0))
			if value != 1.0 and value != 2.0:
				return {"ok": false, "reason": "invalid_speed"}
			state.base_speed = value
			_events.emit("speed_changed", {"value": value})
			return {"ok": true}
		"set_paused":
			state.hard_paused = bool(command.get("value", false))
			_events.emit("pause_changed", {"value": state.hard_paused})
			return {"ok": true}
		"set_held_guest":
			var party_id := int(command.get("party_id", -1))
			state.soft_slow = party_id != -1
			_events.emit("soft_slow_changed", {"active": state.soft_slow, "party_id": party_id})
			return {"ok": true}
		"next_day":
			return _handle_next_day()
		_:
			return {"ok": false, "reason": "unknown_command"}

func _handle_next_day() -> Dictionary:
	if state.phase != "night":
		return {"ok": false, "reason": "not_night"}
	if not state.has_tomorrow_schedule:
		return {"ok": false, "reason": "no_forecast"}

	state.day += 1
	state.phase = "morning"
	state.phase_elapsed = 0.0
	state.today_schedule = state.tomorrow_schedule
	state.tomorrow_schedule = {}
	state.has_tomorrow_schedule = false

	SimEconomyStub.reset_day_metrics(state, state.day)
	_events.emit("phase_changed", {"day": state.day, "phase": "morning"})
	SimRooms.process_checkouts(state, content, _events)
	return {"ok": true}

## Full-state snapshot for tests/save. Syncs the RNG's live state into
## SimState first so it round-trips exactly.
func snapshot() -> Dictionary:
	state.rng_state = _rng.get_state()
	return SimSave.serialize(state)

func save_to_file(path: String = "user://save.json") -> bool:
	state.rng_state = _rng.get_state()
	return SimSave.write_to_file(state, path)

func load_from_file(path: String) -> bool:
	var loaded := SimSave.read_from_file(path)
	if loaded == null:
		return false
	state = loaded
	_rng.seed_with(state.rng_seed)
	_rng.set_state(state.rng_state)
	return true
