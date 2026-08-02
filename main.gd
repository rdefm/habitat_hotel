extends Node

## Temporary console entry point. Subscribes to EventBus like any other view
## would; in interactive mode it prints the loaded data roster once, then
## logs phase/day transitions and a nightly economy summary. With --batch=N
## it instead fast-forwards N days and writes a CSV, then quits. Replaced by
## the real UI/world views in later chunks.

const BatchRunner = preload("res://sim/batch_runner.gd")
const MainScreenScene = preload("res://ui/main_screen.tscn")

var _verify_mode: bool = false
var _days_seen: int = 0
const DEBUG_SCREENSHOT_PATH := "/tmp/godot_debug_screenshot.png"


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		var img := get_viewport().get_texture().get_image()
		img.save_png(DEBUG_SCREENSHOT_PATH)
		print("[Screenshot] Saved %s" % DEBUG_SCREENSHOT_PATH)


func _ready() -> void:
	var args := OS.get_cmdline_args()
	var batch_days := _int_arg(args, "--batch=", -1)

	if batch_days > 0:
		_run_batch_mode(args, batch_days)
		return

	_run_interactive_mode(args)


func _run_batch_mode(args: PackedStringArray, days: int) -> void:
	var policy := _string_arg(args, "--policy=", "")
	var seed_value := _int_arg(args, "--seed=", -1)
	var csv_path := _string_arg(args, "--csv=", BatchRunner.DEFAULT_CSV_PATH)

	print("[Batch] Simulating %d days (policy=%s, seed=%s) -> %s" % [
		days,
		policy if not policy.is_empty() else "default",
		str(seed_value) if seed_value >= 0 else "default",
		csv_path,
	])

	var rows := BatchRunner.run(days, csv_path, seed_value, policy)

	if rows.is_empty():
		print("[Batch] No days simulated.")
		get_tree().quit()
		return

	var last: Dictionary = rows[rows.size() - 1]
	print("[Batch] Done. Day %d: cash=%d hearts=%d reputation=%d occupancy=%.0f%%" % [
		last["day"], last["cash_end"], last["hearts"], last["reputation"], last["occupancy_rate"] * 100.0,
	])
	print("[Batch] Wrote %d rows to %s" % [rows.size(), csv_path])
	get_tree().quit()


func _run_interactive_mode(args: PackedStringArray) -> void:
	_print_roster()

	EventBus.phase_changed.connect(_on_phase_changed)
	EventBus.day_advanced.connect(_on_day_advanced)
	EventBus.day_summary.connect(_on_day_summary)

	if "--verify" in args:
		_verify_mode = true
		Clock.set_speed(40.0)
		print("[Main] --verify flag detected: running clock at 40x speed, will quit after 2 day rollovers")

	if not "--no-ui" in args:
		var ui := MainScreenScene.instantiate()
		add_child(ui)

	var screenshot_path := _string_arg(args, "--screenshot=", "")
	if not screenshot_path.is_empty():
		_capture_screenshot_and_quit(screenshot_path)


func _capture_screenshot_and_quit(path: String) -> void:
	await get_tree().create_timer(1.5).timeout
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("[Screenshot] Saved %s" % path)
	get_tree().quit()


func _int_arg(args: PackedStringArray, prefix: String, default: int) -> int:
	for a in args:
		if a.begins_with(prefix):
			return int(a.substr(prefix.length()))
	return default


func _string_arg(args: PackedStringArray, prefix: String, default: String) -> String:
	for a in args:
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return default


func _print_roster() -> void:
	print("=== Grand Safari Hotel: Data Roster ===")
	print("Tags (%d): %s" % [GameState.tags.size(), ", ".join(GameState.tags.keys())])

	print("--- Species (%d) ---" % GameState.species.size())
	for id in GameState.species.keys():
		var s: Dictionary = GameState.species[id]
		print(" - %s [tier %d] needs=%s likes=%s" % [s["name"], s["tier"], s["needs"], s["likes"]])

	print("--- Rooms (%d) ---" % GameState.rooms.size())
	for id in GameState.rooms.keys():
		var r: Dictionary = GameState.rooms[id]
		print(" - %s tags=%s build_cost=%d unlock_star=%d" % [r["name"], r["tags"], r["build_cost"], r["unlock"]["star"]])

	print("--- Traits (%d) ---" % GameState.traits.size())
	for id in GameState.traits.keys():
		var t: Dictionary = GameState.traits[id]
		print(" - %s: %s" % [t["name"], t["description"]])

	print("--- Starting hotel ---")
	for room in GameState.hotel_rooms:
		var rt: Dictionary = GameState.rooms[room["room_type_id"]]
		print(" - %s #%d: %s" % [rt["name"], room["instance_id"], rt["tags"]])

	print("========================================")


func _on_phase_changed(day: int, phase_name: String) -> void:
	print("[Day %d] %s begins (tick %d)" % [day, phase_name, Clock.tick_in_day])


func _on_day_advanced(day: int) -> void:
	print("[Day %d] ---- new day ----" % day)
	if _verify_mode:
		_days_seen += 1
		if _days_seen >= 2:
			print("[Verify] OK: observed %d full day rollovers through all phases." % _days_seen)
			get_tree().quit()


func _on_day_summary(summary: Dictionary) -> void:
	print("[Day %d] cash=%d (%+d) hearts=%d rep=%d occ=%.0f%% checkouts=%d (+%d/~%d/-%d) arrivals=%d (strict=%d mismatch=%d walked=%d)" % [
		summary["day"], summary["cash_end"], summary["cash_delta"], summary["hearts"], summary["reputation"],
		summary["occupancy_rate"] * 100.0, summary["checkouts"], summary["positive_reviews"], summary["neutral_reviews"], summary["negative_reviews"],
		summary["arrivals"], summary["matched_strict"], summary["matched_mismatched"],
		summary["walked_away_mismatch"] + summary["walked_away_full"] + summary["walked_away_too_expensive"],
	])
