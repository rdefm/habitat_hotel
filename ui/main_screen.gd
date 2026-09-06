extends Control

## Chunk 2 main screen: top bar, a decorative hotel panel, a toast layer
## (ticket 08, ADR-0016; replaces the old scrolling day-log ticker), a
## generic modal overlay, and a bespoke small-popup host (ADR-0011; see
## ui/popup_host.gd). This is the Fun Gate's actual playable surface --
## everything here reads from/writes to GameState via its public API, never
## touching Sim internals directly.
##
## The bottom menu bar (Prices/Hire/Reports/Reviews) is retired (ticket 07,
## ADR-0016): those four menus now live as tabs of ui/reception_menu.gd,
## opened by tapping the Reception structure itself the same way
## _on_terrace_tapped already opens ui/terrace_menu.gd.

const HotelView = preload("res://ui/hotel_view.gd")
const HotelWorld = preload("res://ui/hotel_world.gd")
const HotelPanel = preload("res://ui/hotel_panel.gd")
const ReceptionPanel = preload("res://ui/reception_panel.gd")
const StationPanel = preload("res://ui/station_panel.gd")
const TerracePanel = preload("res://ui/terrace_panel.gd")
const PopupHost = preload("res://ui/popup_host.gd")
const SeatConfirmMenu = preload("res://ui/seat_confirm_menu.gd")
const StayInfoMenu = preload("res://ui/stay_info_menu.gd")
const BuildConfirmMenu = preload("res://ui/build_confirm_menu.gd")
const StafferDetailMenu = preload("res://ui/staffer_detail_menu.gd")
const ReceptionMenu = preload("res://ui/reception_menu.gd")
const UpgradeMenu = preload("res://ui/upgrade_menu.gd")
const TerraceMenu = preload("res://ui/terrace_menu.gd")
const RoomOccupancyLayer = preload("res://ui/room_occupancy_layer.gd")
const StaffJobTravelLayer = preload("res://ui/staff_job_travel_layer.gd")
const ToastLayer = preload("res://ui/toast_layer.gd")

## Ticket 04 (ADR-0020): true mounts the new Node2D world (ui/hotel_world.gd)
## in place of the old Control/ScrollContainer stack (ui/hotel_view.gd);
## false keeps the pre-ADR-0020 view running unchanged. Both stay wired to
## the same GameState/Sim autoloads and both are playable -- flip this
## during development until ticket 17 deletes the old view (and this flag)
## for good. The old view's Reception structure tap has no equivalent in
## the world yet; ticket 07 gave the world Station posts/Staffer tap-drag,
## ticket 08 gave it Room bays (built/Build Slot/empty shell, tap-to-build
## and tap-to-inspect), and ticket 09 gave it the Terrace's signage tap and
## its diner placement, so all three are tappable already.
const USE_HOTEL_WORLD := true

var _cash_label: Label
var _hearts_label: Label
var _reputation_label: Label
var _stars_label: Label
var _day_label: Label
var _season_label: Label
var _pause_button: Button
var _play_button: Button
var _fast_button: Button
var _fit_all_button: Button

var _overlay: Control
var _overlay_title: Label
var _overlay_body: VBoxContainer
var _overlay_content: Control
var _popup_host: PopupHost
var _hotel_world: HotelWorld
var _hotel_panel: HotelPanel
var _reception_panel: ReceptionPanel
var _station_panel: StationPanel
var _room_occupancy_layer: RoomOccupancyLayer
var _staff_job_travel_layer: StaffJobTravelLayer
var _toast_layer: ToastLayer
var _terrace_panel: TerracePanel


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if USE_HOTEL_WORLD:
		_hotel_world = HotelWorld.new()
		add_child(_hotel_world)
		_hotel_world.staffer_tapped.connect(_on_staffer_tapped)
		_hotel_world.room_slot_tapped.connect(_on_hotel_slot_selected)
		_hotel_world.terrace_tapped.connect(_on_terrace_tapped)
		_hotel_world.party_seat_attempted.connect(_on_world_seat_attempted)
	else:
		_build_old_hotel_view()

	## The HUD strip, the modal overlay and the popup host live in a
	## CanvasLayer (ticket 04, ADR-0020) so hotel_world.gd's Camera2D --
	## which now transforms every other CanvasItem in this viewport -- never
	## pans or zooms them. Harmless when USE_HOTEL_WORLD is false too, since
	## with no active Camera2D anywhere a CanvasLayer just renders 1:1.
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)

	var top_bar := _build_top_bar()
	var top_bar_backing := PanelContainer.new()
	top_bar_backing.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var backing_style := StyleBoxFlat.new()
	backing_style.bg_color = Color(0, 0, 0, 0.55)
	top_bar_backing.add_theme_stylebox_override("panel", backing_style)
	top_bar_backing.add_child(top_bar)
	hud_layer.add_child(top_bar_backing)

	_build_overlay(hud_layer)

	_popup_host = PopupHost.new()
	hud_layer.add_child(_popup_host)

	_refresh_top_bar()
	set_process(true)


## The pre-ADR-0020 Control/ScrollContainer view (ticket 02, ADR-0016),
## unchanged except that the top bar it used to sit below has moved into
## the HUD CanvasLayer built by _ready() -- this view now fills the whole
## screen behind that overlay strip rather than sharing a VBoxContainer
## with it.
func _build_old_hotel_view() -> void:
	var hotel_view := HotelView.new()
	hotel_view.interactive = true
	hotel_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(hotel_view)

	_hotel_panel = hotel_view.hotel_panel
	_hotel_panel.slot_selected.connect(_on_hotel_slot_selected)
	_hotel_panel.seat_attempted.connect(_on_seat_attempted)

	_terrace_panel = hotel_view.terrace_panel
	_terrace_panel.terrace_tapped.connect(_on_terrace_tapped)

	_reception_panel = hotel_view.reception_panel
	_reception_panel.party_selected.connect(_on_party_selected)
	_reception_panel.reception_tapped.connect(_on_reception_tapped)

	_station_panel = hotel_view.station_panel
	_station_panel.staffer_tapped.connect(_on_staffer_tapped)

	## Screen-space overlay for the walk-in/persistent-occupant actors
	## (ticket 04, ADR-0016) -- a sibling of hotel_view rather than a child
	## of it, so it draws on top of every floor; mouse_filter IGNORE (set in
	## its own _ready()) keeps it from ever intercepting a tap/drag meant
	## for a RoomCellButton beneath it.
	_room_occupancy_layer = RoomOccupancyLayer.new()
	_room_occupancy_layer.hotel_panel = _hotel_panel
	_room_occupancy_layer.reception_panel = _reception_panel
	add_child(_room_occupancy_layer)

	## Staff Job travel layer (ticket 09, ADR-0016): another screen-space
	## overlay sibling, replacing ui/lobby_view.gd's old decorative,
	## disconnected Housekeeping/Kitchen round-trips with real travel to a
	## Job's actual Room cell or Diner actor.
	_staff_job_travel_layer = StaffJobTravelLayer.new()
	_staff_job_travel_layer.hotel_panel = _hotel_panel
	_staff_job_travel_layer.station_panel = _station_panel
	_staff_job_travel_layer.terrace_panel = _terrace_panel
	add_child(_staff_job_travel_layer)

	## Toast layer (ticket 08, ADR-0016): another screen-space overlay
	## sibling, mounted above _room_occupancy_layer so a toast never renders
	## underneath a walk-in/checkout actor anchored at the same spot.
	_toast_layer = ToastLayer.new()
	_toast_layer.hotel_panel = _hotel_panel
	_toast_layer.reception_panel = _reception_panel
	add_child(_toast_layer)


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

	## Ticket 04 (ADR-0020): the camera's "ease back to fit-all" control.
	## Only meaningful with the Node2D world mounted -- the old view has no
	## camera to reset.
	if USE_HOTEL_WORLD:
		_fit_all_button = Button.new()
		_fit_all_button.text = "Fit All"
		_fit_all_button.pressed.connect(func(): _hotel_world.ease_to_fit_all())
		bar.add_child(_fit_all_button)

	return bar


func _refresh_top_bar() -> void:
	_cash_label.text = "Cash: %d" % GameState.cash
	_cash_label.modulate = Color(1, 0.55, 0.55) if GameState.cash < 0 else Color(1, 1, 1)
	_hearts_label.text = "Hearts: %d" % GameState.hearts
	_reputation_label.text = "Reputation: %d" % GameState.reputation
	_stars_label.text = "%d star" % GameState.stars
	_day_label.text = "Day %d" % GameState.day
	_season_label.text = GameState.season.capitalize()


## --- Hotel panel (the always-visible grid) ---

func _on_hotel_slot_selected(room_type_id: String, instance_id: int) -> void:
	if instance_id == -1:
		var confirm := BuildConfirmMenu.new()
		confirm.room_type_id = room_type_id
		confirm.resolved.connect(func(built: bool):
			_popup_host.close_popup()
			## ui/hotel_world.gd rebuilds its own Room bay actors the moment
			## GameState.hotel_rooms changes (ticket 08) -- only the old
			## Control-based panel needs telling explicitly.
			if built and _hotel_panel != null:
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

## Reception admin modal (ticket 07, ADR-0016: bundles the retired bottom
## menu bar's Prices/Hire/Reports/Reviews as tabs), mirroring
## _on_terrace_tapped's tap-the-structure-for-a-modal pattern.
func _on_reception_tapped() -> void:
	open_menu("Reception", ReceptionMenu.new())


func _on_party_selected(party_id: int) -> void:
	_hotel_panel.selected_party_id = party_id
	_hotel_panel.refresh()


func _on_seat_attempted(party_id: int, room_type_id: String, instance_id: int, hint: String) -> void:
	## Ticket 07 (ADR-0009): a drop can target a Party that isn't the
	## tap-selected one -- _reception_panel.dinner_addon_selected only
	## reflects that selection's checkbox, so it's only correct here when
	## party_id actually is the tap-selected Party. Otherwise fall back to
	## the Party's own persisted opt-in (same seeding reception_panel.gd's
	## _on_card_pressed already does), since a dragged Party never had a
	## checkbox of its own to toggle.
	var dinner_addon := _reception_panel.dinner_addon_selected if party_id == _hotel_panel.selected_party_id else bool(Sim.pending_party(party_id).get("dinner_addon", false))
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


## --- The Node2D world's own seating gesture (ticket 11, ADR-0001/0009) ---
##
## ui/hotel_world.gd's own tap-then-tap (a lobby guest, then a Room bay) and
## drag-a-guest-onto-a-bay gestures both funnel here via party_seat_attempted
## -- same green-auto-seats/amber-opens-the-confirm-modal split as the old
## view's _on_seat_attempted() above, but written fresh rather than reused:
## that handler leans on _hotel_panel/_reception_panel (the tap-selection
## state and the dinner-addon checkbox), neither of which exists under
## USE_HOTEL_WORLD. The world clears its own selection/Needs-bubble state on
## the next rebuild once the seated Party leaves Sim.pending_arrivals, so
## there is nothing for this handler to reset itself.
func _on_world_seat_attempted(party_id: int, room_type_id: String, instance_id: int, hint: String) -> void:
	var dinner_addon := bool(Sim.pending_party(party_id).get("dinner_addon", false))
	if hint == "green":
		Sim.seat_party(party_id, room_type_id, instance_id, dinner_addon)
		return

	var menu := SeatConfirmMenu.new()
	menu.party_id = party_id
	menu.room_type_id = room_type_id
	menu.instance_id = instance_id
	menu.dinner_addon = dinner_addon
	menu.resolved.connect(func(_seated: bool):
		_popup_host.close_popup()
	)
	_popup_host.open_popup(menu)


## --- Modal overlay (generic; auto-pauses the Clock while a menu is open) ---

func _build_overlay(parent: Node) -> void:
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(_overlay)

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
	## Ticket 04 (ADR-0020): null with the world mounted -- none of these
	## panels exist there yet (tickets 06-09), and nothing reachable in the
	## world today opens a menu that would call close_menu() in the first
	## place, but guard anyway rather than assume that stays true.
	if _hotel_panel != null:
		_hotel_panel.refresh()
	if _station_panel != null:
		_station_panel.refresh()
	if _terrace_panel != null:
		_terrace_panel.refresh()
