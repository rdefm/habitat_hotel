class_name StayInfoMenu
extends VBoxContainer

## Bespoke small popup (ADR-0011) shown when tapping a built, occupied Room
## with no Party selected at Reception (ticket 02): the stay's guest name,
## species, fit, and dinner add-on status, plus a way through to the
## existing Upgrade menu so upgrade/price flows aren't lost. Opened via
## main_screen's PopupHost, same as SeatConfirmMenu.

## resolved(open_upgrade): emitted on either button press, mirroring
## SeatConfirmMenu's resolved(seated). main_screen closes the popup either
## way and additionally opens the Upgrade menu when open_upgrade is true.
signal resolved(open_upgrade: bool)

var room_type_id: String = ""
var instance_id: int = -1


func _ready() -> void:
	custom_minimum_size = Vector2(360, 160)

	var room := GameState.room_instance(room_type_id, instance_id)
	var guest_name: String = room.get("occupant_name", "") if room.get("occupant_name", "") else "Guest"
	var species_id: String = room.get("occupant_species_id", "")
	var species_name: String = GameState.species.get(species_id, {}).get("name", species_id)
	var mismatch: bool = room.get("occupant_mismatch", false)
	var dinner_addon: bool = room.get("occupant_dinner_addon", false)
	var fit_text := "mismatch" if mismatch else "perfect fit"

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.text = "%s the %s\n%s%s" % [
		guest_name, species_name, fit_text,
		"\nExpecting dinner service tonight" if dinner_addon else "",
	]
	add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var upgrade_btn := Button.new()
	upgrade_btn.text = "Upgrade Room"
	upgrade_btn.pressed.connect(func(): resolved.emit(true))
	row.add_child(upgrade_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func(): resolved.emit(false))
	row.add_child(close_btn)
