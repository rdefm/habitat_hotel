extends Control

## Presentation entry point. Owns the one SimGame instance, ticks it every
## frame, drains its event outbox, and reflects state into the UI. Never
## mutates sim state directly -- every change goes through sim.submit().

const SimGame = preload("res://sim/sim_game.gd")
const SimMatching = preload("res://sim/sim_matching.gd")
const HotelGrid = preload("res://game/grid/hotel_grid.gd")
const QueueStrip = preload("res://game/queue/queue_strip.gd")
const HudBar = preload("res://game/hud/hud_bar.gd")
const BuildMenu = preload("res://game/build/build_menu.gd")
const SummaryScreen = preload("res://game/summary/summary_screen.gd")
const SpriteFactory = preload("res://game/stubs/sprite_factory.gd")

var sim: SimGame
var _selected_party_id: int = -1
var _paused_by_menu: bool = false
var _last_summary: Dictionary = {}

var hud: HudBar
var queue_strip: QueueStrip
var grid: HotelGrid
var build_menu: BuildMenu
var summary_screen: SummaryScreen
var _context_label: Label

const SAVE_PATH := "user://save.json"

func _ready() -> void:
	sim = SimGame.new("res://data", randi())
	if FileAccess.file_exists(SAVE_PATH):
		sim.load_from_file(SAVE_PATH)
	_build_ui()
	_full_refresh()

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	hud = HudBar.new()
	hud.pause_pressed.connect(_on_pause_pressed)
	hud.speed_1x_pressed.connect(func(): sim.submit({"type": "set_speed", "value": 1.0}))
	hud.speed_2x_pressed.connect(func(): sim.submit({"type": "set_speed", "value": 2.0}))
	root_vbox.add_child(hud)

	queue_strip = QueueStrip.new()
	queue_strip.chip_pressed.connect(_on_chip_pressed)
	root_vbox.add_child(queue_strip)

	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(grid_scroll)
	grid = HotelGrid.new()
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.tile_tapped.connect(_on_tile_tapped)
	grid.tile_drop_requested.connect(_on_tile_drop_requested)
	grid_scroll.add_child(grid)

	var bottom_bar := HBoxContainer.new()
	bottom_bar.custom_minimum_size = Vector2(0, 40)
	root_vbox.add_child(bottom_bar)
	_context_label = SpriteFactory.make_label("", 11)
	_context_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_bar.add_child(_context_label)
	var reopen_btn := Button.new()
	reopen_btn.text = "Last summary"
	reopen_btn.pressed.connect(func():
		if not _last_summary.is_empty():
			_open_summary(_last_summary)
	)
	bottom_bar.add_child(reopen_btn)

	build_menu = BuildMenu.new()
	build_menu.visible = false
	build_menu.room_selected.connect(_on_room_selected)
	build_menu.closed.connect(_on_menu_closed)
	add_child(build_menu)

	summary_screen = SummaryScreen.new()
	summary_screen.visible = false
	summary_screen.next_day_pressed.connect(_on_next_day_pressed)
	add_child(summary_screen)

func _process(delta: float) -> void:
	if not _paused_by_menu:
		sim.advance(delta)

	var needs_grid_refresh := false
	var needs_queue_refresh := false
	for event in sim.drain_events():
		match String(event["type"]):
			"clean_finished":
				grid.flash_fresh(int(event["data"]["plot_id"]))
				needs_grid_refresh = true
			"room_built", "guest_checked_out":
				needs_grid_refresh = true
			"guest_arrived", "guest_seated", "guest_walked":
				needs_queue_refresh = true
				needs_grid_refresh = true
			"day_summary_ready":
				_last_summary = event["data"]
				_open_summary(_last_summary)
				sim.save_to_file(SAVE_PATH)
			_:
				pass

	if needs_grid_refresh:
		_refresh_grid_static()
	if needs_queue_refresh:
		_refresh_queue()
	if _selected_party_id != -1:
		_apply_glow()
	_refresh_hud()
	_refresh_cleaning_progress()
	_refresh_context_label()

## -- Selection / glow --------------------------------------------------

func _on_chip_pressed(party_id: int) -> void:
	if _selected_party_id == party_id:
		_clear_selection()
		return
	_selected_party_id = party_id
	sim.submit({"type": "set_held_guest", "party_id": party_id})
	_apply_glow()

func _clear_selection() -> void:
	if _selected_party_id != -1:
		sim.submit({"type": "set_held_guest", "party_id": -1})
	_selected_party_id = -1
	grid.clear_glow()

func _apply_glow() -> void:
	var entry := _queue_entry_by_party(_selected_party_id)
	if entry == null:
		_clear_selection()
		return
	var fit_by_plot: Dictionary = {}
	for room in sim.get_state().rooms:
		var plot_id := int(room["plot_id"])
		fit_by_plot[plot_id] = _fit_for(_selected_party_id, plot_id)
	grid.apply_glow(fit_by_plot)

## -- Grid interaction ----------------------------------------------------

func _on_tile_tapped(plot_id: int) -> void:
	if _selected_party_id != -1:
		_attempt_seat(_selected_party_id, plot_id)
		return
	var room := _room_by_plot(plot_id)
	if room != null and String(room["state"]) == "empty":
		_open_build_menu(plot_id)

func _on_tile_drop_requested(plot_id: int, party_id: int) -> void:
	_attempt_seat(party_id, plot_id)

func _attempt_seat(party_id: int, plot_id: int) -> void:
	var fit := _fit_for(party_id, plot_id)
	if fit == "NONE":
		return
	if fit == "GOLD":
		_do_seat(party_id, plot_id)
	else:
		_show_amber_confirm(party_id, plot_id)

func _do_seat(party_id: int, plot_id: int) -> void:
	var result := sim.submit({"type": "seat_guest", "party_id": party_id, "plot_id": plot_id})
	if bool(result.get("ok", false)):
		if int(result.get("remainder", 0)) <= 0:
			_clear_selection()
		_refresh_queue()
		_refresh_grid_static()

func _show_amber_confirm(party_id: int, plot_id: int) -> void:
	var room := _room_by_plot(plot_id)
	var entry := _queue_entry_by_party(party_id)
	if room == null or entry == null:
		return
	var content := sim.get_content()
	var room_type: Dictionary = content.rooms.get(room["room_type"], {})
	var species: Dictionary = content.species.get(entry["species_id"], {})
	var missing := SimMatching.missing_needs(room_type.get("tags", []), species.get("needs", []))
	var missing_text := ""
	for i in range(missing.size()):
		missing_text += String(missing[i]).replace("_", " ")
		if i < missing.size() - 1:
			missing_text += ", "

	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "%s isn't %s." % [String(room_type.get("display_name", "")), missing_text]
	dialog.ok_button_text = "Seat"
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)
	_set_paused_by_menu(true)
	dialog.confirmed.connect(func():
		_do_seat(party_id, plot_id)
		dialog.queue_free()
		_set_paused_by_menu(false)
	)
	dialog.canceled.connect(func():
		dialog.queue_free()
		_set_paused_by_menu(false)
	)
	dialog.popup_centered()

## -- Build menu ------------------------------------------------------------

func _open_build_menu(plot_id: int) -> void:
	var max_tier := int(sim.get_content().balance.get("max_room_tier", 99))
	build_menu.open_for_plot(plot_id, sim.get_content().rooms, max_tier, sim.get_state().cash)
	build_menu.visible = true
	_set_paused_by_menu(true)

func _on_room_selected(plot_id: int, room_type_id: String) -> void:
	sim.submit({"type": "build_room", "plot_id": plot_id, "room_type": room_type_id})
	_refresh_grid_static()
	_set_paused_by_menu(false)

func _on_menu_closed() -> void:
	_set_paused_by_menu(false)

## -- Night summary -----------------------------------------------------

func _open_summary(summary: Dictionary) -> void:
	summary_screen.show_summary(summary)
	summary_screen.visible = true
	_set_paused_by_menu(true)

func _on_next_day_pressed() -> void:
	sim.submit({"type": "next_day"})
	summary_screen.visible = false
	_set_paused_by_menu(false)
	_refresh_queue()
	_refresh_grid_static()

## -- Pause / speed ----------------------------------------------------

func _on_pause_pressed() -> void:
	sim.submit({"type": "set_paused", "value": not sim.get_state().hard_paused})

func _set_paused_by_menu(value: bool) -> void:
	_paused_by_menu = value

## -- Refresh helpers -----------------------------------------------------

func _full_refresh() -> void:
	var state := sim.get_state()
	var balance: Dictionary = sim.get_content().balance
	var floors := int(balance.get("grid_floors", 3))
	var per_floor := int(balance.get("grid_plots_per_floor", 4))
	grid.build(state.rooms, sim.get_content().rooms, floors, per_floor)
	_refresh_queue()
	_refresh_hud()

func _refresh_queue() -> void:
	queue_strip.refresh(sim.get_state().queue, sim.get_content().species, sim.get_content().balance)

func _refresh_grid_static() -> void:
	grid.refresh(sim.get_state().rooms, sim.get_content().rooms)
	if _selected_party_id != -1:
		_apply_glow()

func _refresh_hud() -> void:
	var state := sim.get_state()
	var lengths: Dictionary = sim.get_content().balance.get("phase_lengths_sim_seconds", {})
	var phase_length := float(lengths.get(state.phase, 0.0))
	hud.refresh(state.cash, state.day, state.phase, state.phase_elapsed, phase_length)

func _refresh_cleaning_progress() -> void:
	var state := sim.get_state()
	if state.cleaning_plot_id != -1:
		var duration := float(sim.get_content().balance.get("clean_duration_sim_seconds", 14.0))
		grid.set_cleaning_progress(state.cleaning_plot_id, state.cleaning_progress / max(duration, 0.001))

func _refresh_context_label() -> void:
	var state := sim.get_state()
	if state.phase == "night":
		_context_label.text = "Night -- day summary ready."
	elif _selected_party_id != -1:
		_context_label.text = "Guest selected -- tap or drag to a glowing room."
	elif state.queue.is_empty():
		_context_label.text = "Reception is quiet."
	else:
		_context_label.text = "%d part%s waiting." % [state.queue.size(), "y" if state.queue.size() == 1 else "ies"]

## -- Lookups ---------------------------------------------------------------

func _room_by_plot(plot_id: int) -> Variant:
	for room in sim.get_state().rooms:
		if int(room["plot_id"]) == plot_id:
			return room
	return null

func _queue_entry_by_party(party_id: int) -> Variant:
	if party_id == -1:
		return null
	for entry in sim.get_state().queue:
		if int(entry["party_id"]) == party_id:
			return entry
	return null

func _fit_for(party_id: int, plot_id: int) -> String:
	var entry := _queue_entry_by_party(party_id)
	var room := _room_by_plot(plot_id)
	if entry == null or room == null:
		return "NONE"
	var content := sim.get_content()
	var room_type: Dictionary = content.rooms.get(room["room_type"], {})
	var species: Dictionary = content.species.get(entry["species_id"], {})
	return SimMatching.evaluate_fit(room, room_type, species, int(entry["party_count"]))
