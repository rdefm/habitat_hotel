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
## Rooms are identified by room_type_id + instance_id (see ADR-0004), not a
## flat slot index.
signal guest_seated(name: String, species_id: String, room_type_id: String, instance_id: int, mismatch: bool)
signal guest_turned_away(name: String, species_id: String, reason: String)
signal guest_checked_out(name: String, species_id: String, room_type_id: String, instance_id: int)
signal room_marked_dirty(room_type_id: String, instance_id: int)
signal room_cleaned(room_type_id: String, instance_id: int)

## A served dining guest's (Walk-in Diner today; a room guest's dinner
## add-on once ticket 12 lands) Reputation/Hearts outcome (ticket 11,
## ADR-0003) -- Sim's authoritative Hearts/Reputation mutation already
## happened by the time this fires, same "not a source of truth" caveat as
## the guest_* signals above.
signal dining_guest_served(name: String, species_id: String, review: String, satisfaction: float)
signal dining_guest_walked_away(name: String, species_id: String)
