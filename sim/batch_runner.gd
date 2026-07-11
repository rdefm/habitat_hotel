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
	"walked_away_mismatch", "walked_away_full", "checkouts",
	"positive_reviews", "neutral_reviews", "negative_reviews",
	"avg_satisfaction", "upkeep_cost", "wage_cost",
]


## seed_value/policy default to -1/"" as sentinels (rather than referencing
## the Rng/GameState autoload constants directly, which GDScript can't treat
## as constant default-argument expressions); callers that omit them get
## Rng's and GameState's own defaults.
static func run(days: int, csv_path: String = DEFAULT_CSV_PATH, seed_value: int = -1, policy: String = "") -> Array:
	Rng.reset(seed_value) if seed_value >= 0 else Rng.reset()
	Clock.reset()
	if policy.is_empty():
		GameState.reset_to_starting_conditions()
	else:
		GameState.reset_to_starting_conditions(policy)
	Sim.reset()

	var rows: Array = []
	var handler := func(summary: Dictionary): rows.append(summary)
	EventBus.day_summary.connect(handler)

	for d in range(days):
		Clock.force_advance_day()

	EventBus.day_summary.disconnect(handler)

	_write_csv(csv_path, rows)
	return rows


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
