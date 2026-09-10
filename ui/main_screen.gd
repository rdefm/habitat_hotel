extends Control

## Chunk 2 main screen: HUD strip, the Node2D hotel world (ui/hotel_world.gd,
## ADR-0020), a toast layer (ticket 08, ADR-0016; ticket 15, ADR-0020;
## replaces the old scrolling day-log ticker), a generic modal overlay, and a
## bespoke small-popup host (ADR-0011; see ui/popup_host.gd). This is the Fun
## Gate's actual playable surface -- everything here reads from/writes to
## GameState via its public API, never touching Sim internals directly.
##
## The bottom menu bar (Prices/Hire/Reports/Reviews) is retired (ticket 07,
## ADR-0016): those four menus now live as tabs of ui/reception_menu.gd,
## opened by tapping the Reception structure itself the same way
## _on_terrace_tapped already opens ui/terrace_menu.gd.
##
## The world is the game's only play surface (ticket 17): the development
## toggle that let the pre-ADR-0020 Control/ScrollContainer view
## (ui/hotel_view.gd and friends) run alongside ui/hotel_world.gd during the
## migration is gone along with that whole view -- see ADR-0020 and
## .scratch/visual-hotel-world/issues/17-retire-the-old-view.md.

const HotelWorld = preload("res://ui/hotel_world.gd")
const HudStrip = preload("res://ui/hud_strip.gd")
const PopupHost = preload("res://ui/popup_host.gd")
const PixelTheme = preload("res://ui/pixel_theme.gd")
const SeatConfirmMenu = preload("res://ui/seat_confirm_menu.gd")
const StayInfoMenu = preload("res://ui/stay_info_menu.gd")
const BuildConfirmMenu = preload("res://ui/build_confirm_menu.gd")
const StafferDetailMenu = preload("res://ui/staffer_detail_menu.gd")
const ReceptionMenu = preload("res://ui/reception_menu.gd")
const UpgradeMenu = preload("res://ui/upgrade_menu.gd")
const TerraceMenu = preload("res://ui/terrace_menu.gd")
const ToastLayer = preload("res://ui/toast_layer.gd")

var _hud_strip: HudStrip

var _overlay: Control
var _overlay_title: Label
var _overlay_body: VBoxContainer
var _overlay_content: Control
var _popup_host: PopupHost
var _hotel_world: HotelWorld
var _toast_layer: ToastLayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_hotel_world = HotelWorld.new()
	## Ticket 14: set before add_child() so it's already in place when
	## HotelWorld's own _ready() calls ease_to_fit_all(0.0) -- otherwise
	## the very first frame would frame the building under the HUD
	## strip's default (unset) zero margin, then visibly jump once this
	## line ran.
	_hotel_world.hud_top_margin = HudStrip.HEIGHT
	add_child(_hotel_world)
	_hotel_world.staffer_tapped.connect(_on_staffer_tapped)
	_hotel_world.room_slot_tapped.connect(_on_hotel_slot_selected)
	_hotel_world.terrace_tapped.connect(_on_terrace_tapped)
	_hotel_world.reception_tapped.connect(_on_reception_tapped)
	_hotel_world.party_seat_attempted.connect(_on_world_seat_attempted)

	## The HUD strip, the modal overlay and the popup host live in a
	## CanvasLayer (ticket 04, ADR-0020) so hotel_world.gd's Camera2D --
	## which transforms every other CanvasItem in this viewport -- never
	## pans or zooms them.
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)

	_hud_strip = HudStrip.new()
	hud_layer.add_child(_hud_strip)
	_hud_strip.configure(_hotel_world.ease_to_fit_all)

	_build_overlay(hud_layer)

	_popup_host = PopupHost.new()
	hud_layer.add_child(_popup_host)

	## Toast layer (ticket 08, ADR-0016; ticket 15, ADR-0020): another
	## screen-space HUD-layer overlay, tracking each toast's fixed world
	## anchor projected through hotel_world.gd's own camera.
	_toast_layer = ToastLayer.new()
	_toast_layer.hotel_world = _hotel_world
	hud_layer.add_child(_toast_layer)

	set_process(true)


func _process(_delta: float) -> void:
	_hud_strip.refresh()


## --- Room bays (ui/hotel_world.gd's Room floors) ---

func _on_hotel_slot_selected(room_type_id: String, instance_id: int) -> void:
	if instance_id == -1:
		var confirm := BuildConfirmMenu.new()
		confirm.room_type_id = room_type_id
		## ui/hotel_world.gd rebuilds its own Room bay actors the moment
		## GameState.hotel_rooms changes (ticket 08) -- nothing else here
		## needs telling explicitly.
		confirm.resolved.connect(func(_built: bool):
			_popup_host.close_popup()
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
## assignment) -- fired by ui/hotel_world.gd's own staffer_tapped and any
## open TerraceMenu whenever a Staffer card is tapped there. Layers on top
## of whatever's already
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


## --- Reception (tap the structure to open the admin modal -- ADR-0001, ticket 05) ---

## Reception admin modal (ticket 07, ADR-0016: bundles the retired bottom
## menu bar's Prices/Hire/Reports/Reviews as tabs), mirroring
## _on_terrace_tapped's tap-the-structure-for-a-modal pattern -- now opened
## by ui/hotel_world.gd's own reception_tapped (ticket 17).
func _on_reception_tapped() -> void:
	open_menu("Reception", ReceptionMenu.new())


## --- The Node2D world's own seating gesture (ticket 11, ADR-0001/0009) ---
##
## ui/hotel_world.gd's own tap-then-tap (a lobby guest, then a Room bay) and
## drag-a-guest-onto-a-bay gestures both funnel here via party_seat_attempted:
## green auto-seats, amber opens the confirm modal. The world clears its own
## selection/Needs-bubble state on the next rebuild once the seated Party
## leaves Sim.pending_arrivals, so there is nothing for this handler to reset
## itself.
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

	var panel := PixelTheme.themed_panel()
	panel.custom_minimum_size = Vector2(640, 440)
	panel.clip_contents = true
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
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
