extends Node

## Global signal hub. The sim emits through here; UI/world views subscribe.
## No game logic lives on this node.

signal data_loaded

signal tick_advanced(day: int, tick_in_day: int)
signal phase_changed(day: int, phase_name: String)
signal day_advanced(day: int)

signal clock_paused_changed(is_paused: bool)
signal clock_speed_changed(speed: int)

signal day_summary(summary: Dictionary)
signal review_posted(review: Dictionary)
signal forecast_ready(for_day: int, arrivals: Array)

## Per-guest lifecycle events, purely for the lobby view's animation --
## Sim's authoritative state changes (cash, occupant, etc.) already happened
## by the time these fire; nothing should treat them as a source of truth.
signal guest_seated(name: String, species_id: String, room_slot_index: int, mismatch: bool)
signal guest_turned_away(name: String, species_id: String, reason: String)
signal guest_checked_out(name: String, species_id: String, room_slot_index: int)
signal room_marked_dirty(slot_index: int)
signal room_cleaned(slot_index: int)
