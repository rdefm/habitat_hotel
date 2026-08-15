class_name StafferDetailMenu
extends VBoxContainer

## Bespoke small popup (ADR-0011) shown when tapping any Staffer at their
## Station placement -- Reception-area Stations (ui/station_panel.gd,
## ticket 04) or the Terrace's Kitchen slot (ui/terrace_menu.gd, ticket 05).
## Replaces the retired ui/roster_menu.gd as the place to see a Staffer's
## per-Station Skill, Traits, and current assignment (ticket 06). Traits are
## shown defensively via staffer.get("traits", []) since no Staffer carries
## one yet -- ADR-0013's per-Staffer Trait assignment is a separate,
## unimplemented ticket. Opened via main_screen's PopupHost, same as
## SeatConfirmMenu/StayInfoMenu/BuildConfirmMenu.

const Station = preload("res://sim/station.gd")

## Emitted on Close. main_screen just closes the popup -- there's no
## follow-up branch, unlike StayInfoMenu's resolved(open_upgrade).
signal closed

var staffer_id: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(360, 240)
	add_theme_constant_override("separation", 8)

	var staffer: Dictionary = GameState.staffers.get(staffer_id, {})
	var skills: Dictionary = staffer.get("skills", {})

	var header := Label.new()
	header.text = String(staffer.get("name", staffer_id))
	header.add_theme_font_size_override("font_size", 20)
	add_child(header)

	add_child(_section_header("Skill"))
	for station_id in Station.IDS:
		add_child(_label("%s: %d" % [Station.LABELS[station_id], int(skills.get(station_id, 0))]))

	add_child(_section_header("Traits"))
	var trait_ids: Array = staffer.get("traits", [])
	if trait_ids.is_empty():
		add_child(_label("(none)"))
	else:
		for trait_id in trait_ids:
			var trait_data: Dictionary = GameState.traits.get(trait_id, {})
			add_child(_label(String(trait_data.get("name", trait_id))))

	add_child(_section_header("Currently assigned"))
	var current_station := GameState.staffer_station(staffer_id)
	add_child(_label(Station.LABELS.get(current_station, "(unassigned)")))

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): closed.emit())
	add_child(close_btn)


func _section_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	return l


func _label(text: String) -> Label:
	var l := Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.text = text
	return l
