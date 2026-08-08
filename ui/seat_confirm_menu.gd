class_name SeatConfirmMenu
extends VBoxContainer

## The amber-match confirmation (ticket 05, ADR-0001): shown instead of
## seating immediately when the selected Party/Room pair is missing at
## least one Need. Names the missing Need(s) (MatchHint.missing_needs()) so
## the player knows exactly what they're trading away before committing.
## Opened via main_screen's generic modal overlay, same as Build/Upgrade.

const MatchHint = preload("res://sim/match_hint.gd")

## resolved(seated): true if the player confirmed and Sim.seat_party() ran,
## false if they cancelled -- main_screen only clears the Reception
## selection in the former case, so a cancel returns to "still picking a
## Room for this Party" rather than losing the selection.
signal resolved(seated: bool)

## Set by the caller before this node enters the tree. dinner_addon carries
## over whatever ReceptionPanel's opt-in checkbox was set to at the moment
## the seat attempt was made (ticket 12) -- this menu doesn't re-expose its
## own toggle, just honors the choice already made before the Room was
## tapped.
var party_id: int = -1
var room_type_id: String = ""
var instance_id: int = -1
var dinner_addon: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(420, 160)

	var party := Sim.pending_party(party_id)
	var missing := _missing_needs(party)
	var species_name: String = GameState.species.get(party.get("species_id", ""), {}).get("name", party.get("species_id", ""))
	var guest_name: String = party.get("name", "This guest")

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.text = "%s the %s is missing: %s.\nSeating them here means a mismatched stay (lower satisfaction)." % [
		guest_name, species_name, String(", ").join(missing),
	]
	add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Seat anyway"
	confirm_btn.pressed.connect(_on_confirm_pressed)
	row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(_on_cancel_pressed)
	row.add_child(cancel_btn)


func _missing_needs(party: Dictionary) -> Array:
	if party.is_empty():
		return []
	var room := GameState.room_instance(room_type_id, instance_id)
	if room.is_empty():
		return []
	return MatchHint.missing_needs(party, GameState.effective_room_stats(room))


func _on_confirm_pressed() -> void:
	Sim.seat_party(party_id, room_type_id, instance_id, dinner_addon)
	resolved.emit(true)


func _on_cancel_pressed() -> void:
	resolved.emit(false)
