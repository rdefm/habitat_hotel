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
