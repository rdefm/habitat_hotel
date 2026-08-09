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

const PatienceState = preload("res://sim/patience_state.gd")

signal terrace_tapped

const TIER_COLOR := {
	"calm": Color(0.85, 0.95, 1.0),
	"impatient": Color(1.0, 0.75, 0.35),
	"huffy": Color(1.0, 0.45, 0.4),
}

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
	for entry in Sim.breakfast_queue:
		var species_id: String = entry["species_id"]
		var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
		var room_name: String = GameState.rooms.get(entry["room_type_id"], {}).get("name", entry["room_type_id"])
		_breakfast_list.add_child(_label("%s x%d -- %s #%d" % [
			species_name, int(entry["party_size"]), room_name, int(entry["instance_id"]),
		]))


## --- Walk-in dinner queue, with Patience ---

func _refresh_dinner() -> void:
	for child in _dinner_list.get_children():
		child.queue_free()
	if Sim.walkin_queue.is_empty():
		_dinner_list.add_child(_label("No one waiting for dinner."))
		return
	var patience_cfg: Dictionary = GameState.balance["dining"]["walkin_patience"]
	for entry in Sim.walkin_queue:
		var species_id: String = entry["species_id"]
		var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
		var tier := PatienceState.tier(float(entry["patience"]), patience_cfg)
		var addon_note := " (Room add-on)" if int(entry.get("guest_id", -1)) != -1 else ""
		var line := _label("%s the %s x%d -- %s%s" % [
			entry["name"], species_name, int(entry["party_size"]), tier.capitalize(), addon_note,
		])
		line.modulate = TIER_COLOR[tier]
		_dinner_list.add_child(line)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
