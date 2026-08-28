class_name TerracePanel
extends VBoxContainer

## The Terrace's always-visible ambient view (ticket 05, ADR-0010): the
## structure itself is a tappable button (terrace_tapped) that main_screen
## opens as a modal (ui/terrace_menu.gd) via the generic overlay for Kitchen
## staffing, the Daily Special picker, and the Terrace Upgrades shop. The
## current Daily Special and the breakfast/dinner queues -- each dinner
## entry showing its Patience tier (sim/patience_state.gd, same
## calm/impatient/huffy tiers/colors as ui/reception_panel.gd) -- stay
## visible here without opening anything, mirroring how Reception's own
## arrival queue is already always on screen.
##
## Refreshes on every EventBus.tick_advanced/phase_changed since Patience
## needs to visibly tick down live (reception_panel.gd's same tradeoff);
## main_screen also calls refresh() when the generic overlay closes, since a
## Daily Special change or Kitchen (re)assignment made in the modal doesn't
## fire its own signal back to this panel.
##
## Stacking (ticket 09, ADR-0008/0009): each breakfast/dinner queue entry is a
## QueueEntryButton, a drop target for a Staffer card (ui/staffer_card.gd's
## StafferCardButton) dropped onto an entry currently being served, Stacking
## them onto that Kitchen Job via Sim.can_stack_staffer_on_breakfast()/
## stack_staffer_on_breakfast() (or the _dinner equivalents) -- rejected (no
## state change, the dragged card's own reject-flash) for an entry with no
## in-flight Job at all or one already at Sim.STACK_CAP, mirroring
## ui/hotel_panel.gd's RoomCellButton.
##
## Actor reskin (ticket 06, ADR-0016): QueueEntryButton itself, its
## drop-target validation, and every Stacking call above are unchanged --
## only _make_breakfast_actor()/_make_dinner_actor()'s visuals shrink from a
## wide single-line info row to a narrow standing token, mirroring
## ui/reception_panel.gd's guest actors (ticket 03) down to sharing
## ui/actor_style.gd's flat, rounded look and TIER_COLOR palette (via the
## shared _style_actor()/_actor_caption()/_make_actor_row() helpers both
## queues' builders call). The dinner queue keeps its Patience-tier tint
## (walk-in Diners decay Patience just like the Reception queue); the
## breakfast queue -- one guest per already-occupied Room, no Patience field
## at all -- renders as a plain untinted token. Full detail that used to live
## in the row's text now lives in tooltip_text instead.

const PatienceState = preload("res://sim/patience_state.gd")
const ActorStyle = preload("res://ui/actor_style.gd")

signal terrace_tapped

class QueueEntryButton extends Button:
	signal staffer_dropped(staffer_id: String)

	var kind: String = "" # "breakfast" or "dinner"
	var entry_id: int = -1

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if typeof(data) != TYPE_DICTIONARY or data.get("type") != "staffer":
			return false
		var staffer_id := String(data["staffer_id"])
		if kind == "breakfast":
			return Sim.can_stack_staffer_on_breakfast(staffer_id, entry_id)
		return Sim.can_stack_staffer_on_dinner(staffer_id, entry_id)

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		staffer_dropped.emit(String(data["staffer_id"]))

const TIER_COLOR := {
	"calm": Color(0.85, 0.95, 1.0),
	"impatient": Color(1.0, 0.75, 0.35),
	"huffy": Color(1.0, 0.45, 0.4),
}

const ACTOR_MIN_SIZE := Vector2(44, 64)

var _special_label: Label
var _breakfast_list: VBoxContainer
var _dinner_list: VBoxContainer


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var tap_btn := Button.new()
	tap_btn.text = "Terrace -- tap for Kitchen staffing, Special, Upgrades"
	tap_btn.pressed.connect(func(): terrace_tapped.emit())
	add_child(tap_btn)

	_special_label = Label.new()
	add_child(_special_label)

	add_child(_section_header("Breakfast Queue"))
	_breakfast_list = VBoxContainer.new()
	add_child(_breakfast_list)

	add_child(_section_header("Walk-in Dinner Queue"))
	_dinner_list = VBoxContainer.new()
	add_child(_dinner_list)

	refresh()
	EventBus.tick_advanced.connect(func(_d, _t): refresh())
	EventBus.phase_changed.connect(func(_d, _p): refresh())


func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 16)
	return l


func refresh() -> void:
	_refresh_special()
	_refresh_breakfast()
	_refresh_dinner()


## --- Daily Special (current pick only; the picker itself lives in the modal) ---

func _refresh_special() -> void:
	var special_id: String = GameState.daily_special
	var special_name := "(none)" if special_id == "" else String(GameState.species.get(special_id, {}).get("name", special_id))
	_special_label.text = "Today's Special: %s" % special_name


## --- Breakfast queue ---

func _refresh_breakfast() -> void:
	for child in _breakfast_list.get_children():
		child.queue_free()

	if Sim.breakfast_queue.is_empty():
		_breakfast_list.add_child(_label("No one waiting for breakfast."))
		return

	var row := _make_actor_row(_breakfast_list)
	for entry in Sim.breakfast_queue:
		row.add_child(_make_breakfast_actor(entry))


func _make_breakfast_actor(entry: Dictionary) -> Button:
	var species_id: String = entry["species_id"]
	var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
	var room_name: String = GameState.rooms.get(entry["room_type_id"], {}).get("name", entry["room_type_id"])
	var party_size := int(entry["party_size"])
	var entry_id: int = int(entry["id"])

	var btn := QueueEntryButton.new()
	btn.kind = "breakfast"
	btn.entry_id = entry_id
	_style_actor(btn)
	btn.text = _actor_caption(species_name, party_size)
	btn.modulate = Color(1, 1, 1)
	btn.tooltip_text = "%s -- %d guest(s) -- %s #%d" % [
		species_name, party_size, room_name, int(entry["instance_id"]),
	]
	btn.staffer_dropped.connect(func(staffer_id: String):
		Sim.stack_staffer_on_breakfast(staffer_id, entry_id)
	)
	return btn


## --- Walk-in dinner queue, with Patience ---

func _refresh_dinner() -> void:
	for child in _dinner_list.get_children():
		child.queue_free()

	if Sim.walkin_queue.is_empty():
		_dinner_list.add_child(_label("No one waiting for dinner."))
		return

	var row := _make_actor_row(_dinner_list)
	var patience_cfg: Dictionary = GameState.balance["dining"]["walkin_patience"]
	for entry in Sim.walkin_queue:
		row.add_child(_make_dinner_actor(entry, patience_cfg))


func _make_dinner_actor(entry: Dictionary, patience_cfg: Dictionary) -> Button:
	var species_id: String = entry["species_id"]
	var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
	var tier := PatienceState.tier(float(entry["patience"]), patience_cfg)
	var addon_note := " (Room add-on)" if int(entry.get("guest_id", -1)) != -1 else ""
	var party_size := int(entry["party_size"])
	var entry_id: int = int(entry["id"])

	var btn := QueueEntryButton.new()
	btn.kind = "dinner"
	btn.entry_id = entry_id
	_style_actor(btn)
	btn.text = _actor_caption(species_name, party_size)
	btn.modulate = TIER_COLOR[tier]
	btn.tooltip_text = "%s the %s -- %d guest(s), %s%s" % [
		entry["name"], species_name, party_size, tier.capitalize(), addon_note,
	]
	btn.staffer_dropped.connect(func(staffer_id: String):
		Sim.stack_staffer_on_dinner(staffer_id, entry_id)
	)
	return btn


## Shared by both queues' _make_*_actor(): a ScrollContainer'd HBoxContainer
## of tokens, appended to parent -- mirrors ui/reception_panel.gd's own
## queue-scroll setup (ticket 03).
func _make_actor_row(parent: Container) -> HBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, ACTOR_MIN_SIZE.y + 8)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	scroll.add_child(row)
	return row


## Shared by both queues' _make_*_actor(): strips a QueueEntryButton down to
## ui/actor_style.gd's flat, rounded look on every Button state, per
## ADR-0015/0016's "plain colored shapes" actors.
func _style_actor(btn: Button) -> void:
	btn.custom_minimum_size = ACTOR_MIN_SIZE
	btn.clip_text = true
	btn.add_theme_stylebox_override("normal", ActorStyle.flat_box())
	btn.add_theme_stylebox_override("hover", ActorStyle.flat_box())
	btn.add_theme_stylebox_override("pressed", ActorStyle.flat_box())
	btn.add_theme_stylebox_override("focus", ActorStyle.flat_box())


## Shared by both queues' _make_*_actor(): a species initial plus a party-size
## line, mirroring ui/reception_panel.gd's _make_actor() caption.
func _actor_caption(species_name: String, party_size: int) -> String:
	var caption := species_name.left(3)
	if party_size > 1:
		caption += "\n×%d" % party_size
	return caption


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
