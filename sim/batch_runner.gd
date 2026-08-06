class_name BatchRunner
extends RefCounted

## Fast-forwards N days with no real-time wait (via Clock.force_advance_day),
## collecting each EventBus.day_summary into a CSV. The balancing tool
## described in section 6: tune data/balance.json, re-run, read the CSV --
## never tune by editing sim code.

const OUTPUT_DIR := "res://debug_output"
const DEFAULT_CSV_PATH := OUTPUT_DIR + "/batch_report.csv"

const CSV_COLUMNS := [
	"day", "cash_start", "cash_end", "cash_delta", "hearts", "reputation",
	"occupancy_rate", "arrivals", "matched_strict", "matched_mismatched",
	"walked_away_mismatch", "walked_away_full", "walked_away_too_expensive", "checkouts",
	"positive_reviews", "neutral_reviews", "negative_reviews",
	"avg_satisfaction", "upkeep_cost", "wage_cost",
]


## seed_value defaults to -1 as a sentinel (rather than referencing the Rng
## autoload constant directly, which GDScript can't treat as a constant
## default-argument expression); callers that omit it get Rng's own default.
##
## Arrivals are seated the same manual way interactive play seats them (see
## ADR-0001/Sim.seat_party()), driven by the scripted autopilot rule in
## _seat_pending_arrivals() every Morning.
static func run(days: int, csv_path: String = DEFAULT_CSV_PATH, seed_value: int = -1) -> Array:
	Rng.reset(seed_value) if seed_value >= 0 else Rng.reset()
	Clock.reset()
	GameState.reset_to_starting_conditions()
	Sim.reset()

	var rows: Array = []
	var summary_handler := func(summary: Dictionary): rows.append(summary)
	var morning_handler := func(_day: int, phase_name: String):
		if phase_name == "MORNING":
			_seat_pending_arrivals()
	EventBus.day_summary.connect(summary_handler)
	EventBus.phase_changed.connect(morning_handler)

	for d in range(days):
		Clock.force_advance_day()

	EventBus.day_summary.disconnect(summary_handler)
	EventBus.phase_changed.disconnect(morning_handler)

	_write_csv(csv_path, rows)
	return rows


## The scripted autopilot rule (see
## .scratch/direct-manipulation-core-loop/issues/06-batch-runner-autopilot.md):
## every Party still in Sim.pending_arrivals is matched, through Sim.seat_party()
## -- the same single admission path interactive play uses -- to the smallest-
## capacity green Room available, falling back to the smallest-capacity amber
## Room, and left untouched in the queue if neither exists (its own Patience
## then decides when it walks away). An oversized Party keeps matching against
## whatever remains of it (see Sim.seat_party()'s split-across-rooms behavior)
## until no Room fits.
static func _seat_pending_arrivals() -> void:
	var party_ids: Array = []
	for party in Sim.pending_arrivals:
		party_ids.append(int(party["id"]))

	for party_id in party_ids:
		var room := _best_room_for(party_id)
		while not room.is_empty():
			if not Sim.seat_party(party_id, room["room_type_id"], int(room["instance_id"])):
				break
			room = _best_room_for(party_id)


## The autopilot rule's room choice for party_id right now: the smallest-
## capacity green match, else the smallest-capacity amber match, else {} (no
## Room worth tapping). Pure query, built on the same Sim.match_hint() the
## interactive UI uses for its own green/amber highlighting.
static func _best_room_for(party_id: int) -> Dictionary:
	var best: Dictionary = {}
	var best_hint := ""
	var best_capacity := 0

	for room in GameState.hotel_rooms:
		var hint := Sim.match_hint(party_id, room["room_type_id"], int(room["instance_id"]))
		if hint == "none":
			continue
		var capacity := int(GameState.effective_room_stats(room)["capacity"])
		if _is_better_match(hint, capacity, best_hint, best_capacity):
			best = room
			best_hint = hint
			best_capacity = capacity

	return best


## green always outranks amber regardless of capacity; within the same hint,
## smaller capacity wins.
static func _is_better_match(hint: String, capacity: int, best_hint: String, best_capacity: int) -> bool:
	if best_hint.is_empty():
		return true
	if hint == best_hint:
		return capacity < best_capacity
	return hint == "green"


static func _write_csv(path: String, rows: Array) -> void:
	var dir := DirAccess.open("res://")
	if dir == null:
		push_error("[BatchRunner] Could not open res:// to ensure output dir exists")
		return
	dir.make_dir_recursive(OUTPUT_DIR.trim_prefix("res://"))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("[BatchRunner] Could not open %s for writing (error %d)" % [path, FileAccess.get_open_error()])
		return

	file.store_line(",".join(CSV_COLUMNS))
	for row in rows:
		var values: Array = []
		for col in CSV_COLUMNS:
			values.append(str(row.get(col, "")))
		file.store_line(",".join(values))
	file.close()
