extends Control

## Chunk 2 main screen: top bar, menu buttons, a decorative hotel panel, a
## day log ticker, a generic modal overlay, and a bespoke small-popup host
## (ADR-0011; see ui/popup_host.gd). This is the Fun Gate's actual playable
## surface -- everything here reads from/writes to GameState via its public
## API, never touching Sim internals directly.

const HotelPanel = preload("res://ui/hotel_panel.gd")
const ReceptionPanel = preload("res://ui/reception_panel.gd")
const StationPanel = preload("res://ui/station_panel.gd")
const TerracePanel = preload("res://ui/terrace_panel.gd")
const PopupHost = preload("res://ui/popup_host.gd")
const SeatConfirmMenu = preload("res://ui/seat_confirm_menu.gd")
const StayInfoMenu = preload("res://ui/stay_info_menu.gd")
const BuildConfirmMenu = preload("res://ui/build_confirm_menu.gd")
const StafferDetailMenu = preload("res://ui/staffer_detail_menu.gd")
const PricesMenu = preload("res://ui/prices_menu.gd")
const HireMenu = preload("res://ui/hire_menu.gd")
const ReportsMenu = preload("res://ui/reports_menu.gd")
const ReviewsMenu = preload("res://ui/reviews_menu.gd")
const UpgradeMenu = preload("res://ui/upgrade_menu.gd")
const TerraceMenu = preload("res://ui/terrace_menu.gd")
const LobbyView = preload("res://ui/lobby_view.gd")
const DemandFormat = preload("res://ui/demand_format.gd")

const DAY_LOG_MAX_LINES := 200

var _cash_label: Label
var _hearts_label: Label
var _reputation_label: Label
var _stars_label: Label
var _day_label: Label
var _season_label: Label
var _pause_button: Button
var _play_button: Button
var _fast_button: Button

var _day_log: RichTextLabel

var _overlay: Control
var _overlay_title: Label
var _overlay_body: VBoxContainer
var _overlay_content: Control
var _popup_host: PopupHost
var _hotel_panel: HotelPanel
var _reception_panel: ReceptionPanel
var _station_panel: StationPanel
var _terrace_panel: TerracePanel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_menu_bar())
	root.add_child(LobbyView.new())

	_reception_panel = ReceptionPanel.new()
	_reception_panel.party_selected.connect(_on_party_selected)
	root.add_child(_reception_panel)

	_station_panel = StationPanel.new()
	_station_panel.staffer_tapped.connect(_on_staffer_tapped)
	root.add_child(_station_panel)

	_terrace_panel = TerracePanel.new()
	_terrace_panel.terrace_tapped.connect(_on_terrace_tapped)
	root.add_child(_terrace_panel)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(middle)

	_hotel_panel = HotelPanel.new()
	_hotel_panel.interactive = true
	_hotel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hotel_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_hotel_panel.slot_selected.connect(_on_hotel_slot_selected)
	_hotel_panel.seat_attempted.connect(_on_seat_attempted)
	middle.add_child(_hotel_panel)

	root.add_child(_build_day_log())

	_build_overlay()

	_popup_host = PopupHost.new()
	add_child(_popup_host)

	EventBus.day_summary.connect(_on_day_summary)
	EventBus.review_posted.connect(_on_review_posted)
	EventBus.forecast_ready.connect(_on_forecast_ready)

	_log("Welcome to Grand Safari Hotel. Day 1 begins.")
	_refresh_top_bar()
	set_process(true)


func _process(_delta: float) -> void:
	_refresh_top_bar()


## --- Top bar ---

func _build_top_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 18)

	_cash_label = Label.new()
	_hearts_label = Label.new()
	_reputation_label = Label.new()
	_stars_label = Label.new()
	_day_label = Label.new()
	_season_label = Label.new()
	for l in [_cash_label, _hearts_label, _reputation_label, _stars_label, _day_label, _season_label]:
		bar.add_child(l)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)

	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.pressed.connect(func(): Clock.set_paused(true))
	bar.add_child(_pause_button)

	_play_button = Button.new()
	_play_button.text = "1x"
	_play_button.pressed.connect(func():
		Clock.set_paused(false)
		Clock.set_speed(1.0)
	)
	bar.add_child(_play_button)

	_fast_button = Button.new()
	_fast_button.text = "2x"
	_fast_button.pressed.connect(func():
		Clock.set_paused(false)
		Clock.set_speed(2.0)
	)
	bar.add_child(_fast_button)

	return bar


func _refresh_top_bar() -> void:
	_cash_label.text = "Cash: %d" % GameState.cash
	_cash_label.modulate = Color(1, 0.55, 0.55) if GameState.cash < 0 else Color(1, 1, 1)
	_hearts_label.text = "Hearts: %d" % GameState.hearts
	_reputation_label.text = "Reputation: %d" % GameState.reputation
	_stars_label.text = "%d star" % GameState.stars
	_day_label.text = "Day %d" % GameState.day
	_season_label.text = GameState.season.capitalize()


## --- Menu bar ---

func _build_menu_bar() -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)

	var entries := [
		["Prices", func(): return PricesMenu.new()],
		["Hire", func(): return HireMenu.new()],
		["Reports", func(): return ReportsMenu.new()],
		["Reviews", func(): return ReviewsMenu.new()],
	]
	for entry in entries:
		var label: String = entry[0]
		var factory: Callable = entry[1]
		var btn := Button.new()
		btn.text = label
		btn.pressed.connect(func(): open_menu(label, factory.call()))
		bar.add_child(btn)

	return bar


## --- Hotel panel (the always-visible grid) ---

func _on_hotel_slot_selected(room_type_id: String, instance_id: int) -> void:
	if instance_id == -1:
		var confirm := BuildConfirmMenu.new()
		confirm.room_type_id = room_type_id
		confirm.resolved.connect(func(built: bool):
			_popup_host.close_popup()
			if built:
				_hotel_panel.refresh()
		)
		_popup_host.open_popup(confirm)
		return

	var room := GameState.room_instance(room_type_id, instance_id)
	if room["occupant"] != null:
		var info := StayInfoMenu.new()
		info.room_type_id = room_type_id
		info.instance_id = instance_id
		info.resolved.connect(func(open_upgrade: bool):
			_popup_host.close_popup()
			if open_upgrade:
				_open_upgrade_menu(room_type_id, instance_id)
		)
		_popup_host.open_popup(info)
		return

	_open_upgrade_menu(room_type_id, instance_id)


## --- Terrace (ticket 05, ADR-0010: always-visible structure, tap for the modal) ---

func _on_terrace_tapped() -> void:
	var menu := TerraceMenu.new()
	menu.staffer_tapped.connect(_on_staffer_tapped)
	open_menu("Terrace", menu)


## --- Staffer detail popup (ticket 06, ADR-0011: replaces the retired
## ui/roster_menu.gd as the place to see a Staffer's Skill/Traits/current
## assignment) -- fired by _station_panel and any open TerraceMenu whenever
## a Staffer card is tapped there. Layers on top of whatever's already
## showing via PopupHost, which renders after (and so on top of) the
## generic overlay. PopupHost.close_popup() unconditionally resumes the
## Clock, which would wrongly un-pause a still-open TerraceMenu underneath
## (the Kitchen-slot case) -- so re-pause it here if the generic overlay is
## still visible.

func _on_staffer_tapped(staffer_id: String) -> void:
	var detail := StafferDetailMenu.new()
	detail.staffer_id = staffer_id
	detail.closed.connect(func():
		_popup_host.close_popup()
		if _overlay.visible:
			Clock.set_paused(true)
	)
	_popup_host.open_popup(detail)


func _open_upgrade_menu(room_type_id: String, instance_id: int) -> void:
	var room_name: String = GameState.rooms[room_type_id]["name"]
	var menu := UpgradeMenu.new()
	menu.room_type_id = room_type_id
	menu.instance_id = instance_id
	open_menu("Upgrade %s #%d" % [room_name, instance_id], menu)


## --- Reception (tap a Party, then tap a Room to seat -- ADR-0001, ticket 05) ---

func _on_party_selected(party_id: int) -> void:
	_hotel_panel.selected_party_id = party_id
	_hotel_panel.refresh()


func _on_seat_attempted(party_id: int, room_type_id: String, instance_id: int, hint: String) -> void:
	var dinner_addon := _reception_panel.dinner_addon_selected
	if hint == "green":
		Sim.seat_party(party_id, room_type_id, instance_id, dinner_addon)
		_finish_seating_flow()
		return

	var menu := SeatConfirmMenu.new()
	menu.party_id = party_id
	menu.room_type_id = room_type_id
	menu.instance_id = instance_id
	menu.dinner_addon = dinner_addon
	menu.resolved.connect(func(seated: bool):
		_popup_host.close_popup()
		if seated:
			_finish_seating_flow()
		else:
			_hotel_panel.refresh()
	)
	_popup_host.open_popup(menu)


func _finish_seating_flow() -> void:
	_reception_panel.clear_selection()
	_hotel_panel.selected_party_id = -1
	_hotel_panel.refresh()


## --- Day log ---

func _build_day_log() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 140)

	_day_log = RichTextLabel.new()
	_day_log.bbcode_enabled = true
	_day_log.scroll_following = true
	_day_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(_day_log)
	return panel


func _log(line: String) -> void:
	_day_log.append_text(line + "\n")


func _on_day_summary(summary: Dictionary) -> void:
	var turned_away: int = summary["walked_away_mismatch"] + summary["walked_away_full"] + summary["walked_away_too_expensive"]
	_log("[b]Day %d[/b] cash %+d, occupancy %.0f%%, %d checkout(s), %d arrival(s), %d turned away" % [
		summary["day"], summary["cash_delta"], summary["occupancy_rate"] * 100.0, summary["checkouts"],
		summary["arrivals"], turned_away,
	])
	if turned_away > 0:
		_log("  [color=orange]turned away:[/color] %s" % DemandFormat.summarize_counts(summary["turned_away_species"], GameState.species))


func _on_review_posted(review: Dictionary) -> void:
	var color: String = {"positive": "green", "negative": "red"}.get(review["review"], "gray")
	var guest_name: String = review.get("guest_name", "") if review.get("guest_name", "") else "Guest"
	_log("  [color=%s]%s the %s[/color] (%s, %+d cash) -- \"%s\"" % [
		color, guest_name, review["species_name"], review["review"], review["revenue"], review["flavor_line"],
	])


func _on_forecast_ready(for_day: int, arrivals: Array) -> void:
	_log("[color=cyan]Forecast for Day %d:[/color] %s" % [for_day, DemandFormat.summarize_arrivals(arrivals, GameState.species)])


## --- Modal overlay (generic; auto-pauses the Clock while a menu is open) ---

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_overlay)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.5)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 440)
	panel.clip_contents = true
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	_overlay_title = Label.new()
	_overlay_title.add_theme_font_size_override("font_size", 20)
	_overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_overlay_title)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(close_menu)
	header.add_child(close_btn)

	_overlay_body = VBoxContainer.new()
	_overlay_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_overlay_body)


func open_menu(title: String, content: Control) -> void:
	if _overlay_content != null:
		_overlay_content.queue_free()
	_overlay_content = content
	_overlay_title.text = title
	_overlay_body.add_child(content)
	_overlay.visible = true
	Clock.set_paused(true)


func close_menu() -> void:
	_overlay.visible = false
	if _overlay_content != null:
		_overlay_content.queue_free()
		_overlay_content = null
	Clock.set_paused(false)
	_hotel_panel.refresh()
	_station_panel.refresh()
	_terrace_panel.refresh()
