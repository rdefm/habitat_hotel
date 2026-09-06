class_name RoomBayActor
extends Node2D

## One Room floor bay -- a built Room, a Build Slot, or an empty shell
## (ticket 08, sim/building_layout.gd's room_bay_states()). No bay-specific
## painted art exists yet, so every bay draws as a plain tinted rect plus
## Labels; the mess overlay and any purchased-upgrade props DO go through
## BuildingLayout's fallback-rule resolvers (resolve_mess_overlay()/
## resolve_upgrade_prop()), same as every other slot in the asset contract.
##
## ui/hotel_world.gd owns tap hit-testing against hit_rect() and the actual
## GameState/Sim call a tap resolves to (opening the build-confirm flow or
## the stay-info modal); this class only draws and reports its own
## footprint, same division of labour as ui/staffer_actor.gd. Ticket 11
## reuses that same hit_rect() as the drop target for seating a dragged
## guest, and adds set_match_hint() for the green/amber Match hint glow.

const CharacterSprite = preload("res://ui/character_sprite.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")

const BUILD_SLOT_TINT := Color(0.3, 0.65, 0.35, 0.4)
const EMPTY_SHELL_TINT := Color(0.05, 0.05, 0.05, 0.5)
const BUILT_TINT := Color(0, 0, 0, 0)

## Ticket 13: the mess overlay's alpha floor at full Job progress (visual_state's
## "mess_progress" == 0.0) -- never fully invisible mid-Job, since the Room is
## still dirty until needs_cleaning actually flips false and the overlay stops
## being added at all (ui/hotel_world.gd's own _rebuild_room_bays()). Alpha
## between this floor and 1.0 (freshly dirtied, no Staffer working it yet) is
## a straight lerp against the Job's own ticks_remaining fraction.
const MESS_OVERLAY_MIN_ALPHA := 0.2

## Ticket 11's Match hint glow, drawn as a translucent overlay above a built
## bay's own content (so a door plate/upgrade prop under it stays legible)
## rather than replacing _background's tint -- a bay's occupancy/dirt/
## upgrade state and its Match hint are two independent things that can
## both be true at once (a dirty-but-vacant Room can still glow). Keyed by
## MatchHint's own "green"/"amber" vocabulary; "none" (or any other value)
## clears the glow rather than drawing one.
const MATCH_HINT_COLORS := {
	"green": Color(0.4, 1.0, 0.4, 0.45),
	"amber": Color(1.0, 0.75, 0.3, 0.45),
}

## Room type id and bay state this actor is currently showing -- read by
## ui/hotel_world.gd's hit-testing to decide what a tap on this bay means
## (a Build Slot vs. an already-built Room's instance_id) and to skip an
## empty shell entirely, since it isn't a tap target.
var room_type_id: String = ""
var state: String = "empty"
var instance_id: int = -1

var _bay_size := Vector2.ZERO
var _background: ColorRect
var _glow: ColorRect = null


func configure(new_room_type_id: String, bay_state: Dictionary, bay_size: Vector2, room_number: int, visual_state: Dictionary) -> void:
	for child in get_children():
		child.queue_free()

	room_type_id = new_room_type_id
	state = String(bay_state["state"])
	instance_id = int(bay_state["instance_id"])
	_bay_size = bay_size

	_background = ColorRect.new()
	_background.size = bay_size
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	match state:
		"build_slot":
			_background.color = BUILD_SLOT_TINT
			_add_label("Build Slot\n(tap to build)", Vector2.ZERO, bay_size, 13)
		"empty":
			_background.color = EMPTY_SHELL_TINT
		"built":
			_background.color = BUILT_TINT
			_add_door_plate(room_number)
			if bool(visual_state.get("dirty", false)):
				_add_mess_overlay(float(visual_state.get("mess_progress", 1.0)))
			_add_upgrade_props(visual_state.get("upgrade_ids", []))


func hit_rect() -> Rect2:
	return Rect2(global_position, _bay_size)


## Ticket 11: applies (or clears) the Match hint glow for whatever Party is
## currently selected/dragged -- called independently of configure(), which
## only runs on a structural rebuild (a build/checkout/clean/upgrade), so a
## guest tap or pick-up can re-glow every built bay without tearing down and
## recreating its whole subtree. `hint` is BuildingLayout.room_bay_match_hint()'s
## own vocabulary; anything not in MATCH_HINT_COLORS (typically "none")
## clears an existing glow instead of drawing one.
func set_match_hint(hint: String) -> void:
	if not MATCH_HINT_COLORS.has(hint):
		if _glow != null:
			_glow.queue_free()
			_glow = null
		return

	if _glow == null:
		_glow = ColorRect.new()
		_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_glow.size = _bay_size
		add_child(_glow)
	_glow.color = MATCH_HINT_COLORS[hint]


func _add_door_plate(room_number: int) -> void:
	var plate := Label.new()
	plate.text = "#%d" % room_number
	plate.position = Vector2(4, 4)
	plate.add_theme_font_size_override("font_size", 12)
	plate.add_theme_color_override("font_color", Color(1, 1, 1))
	plate.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	plate.add_theme_constant_override("shadow_offset_x", 1)
	plate.add_theme_constant_override("shadow_offset_y", 1)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(plate)


## Centered over the bay -- a dirty Room's mess is meant to read at a
## glance from across the building (spec.md story 30), not tucked in a
## corner alongside the door plate or upgrade props. `progress` (ticket 13,
## ui/hotel_world.gd's _room_mess_progress()) fades it toward
## MESS_OVERLAY_MIN_ALPHA as the Room's Housekeeping Job counts down, so
## cleaning progress is something the player watches rather than infers
## (spec.md story 31) -- 1.0 (fully opaque) for a dirty-but-unclaimed Room.
func _add_mess_overlay(progress: float) -> void:
	var overlay := CharacterSprite.new()
	add_child(overlay)
	overlay.configure(BuildingLayout.resolve_mess_overlay())
	overlay.position = _bay_size / 2.0 + Vector2(0, BuildingLayout.MESS_OVERLAY_SIZE / 2.0)
	overlay.modulate.a = lerpf(MESS_OVERLAY_MIN_ALPHA, 1.0, progress)


## Right-aligned along the bay's bottom edge, one prop per purchased
## upgrade id, so multiple upgrades on the same Room stack side by side
## instead of overlapping -- same STAFFER_STACK_OFFSET-style spacing
## sim/building_layout.gd already uses for Staffers sharing a post.
func _add_upgrade_props(upgrade_ids: Array) -> void:
	for i in range(upgrade_ids.size()):
		var prop := CharacterSprite.new()
		add_child(prop)
		prop.configure(BuildingLayout.resolve_upgrade_prop(String(upgrade_ids[i])))
		var x: float = _bay_size.x - 8.0 - float(i) * (BuildingLayout.UPGRADE_PROP_SIZE + 6.0)
		prop.position = Vector2(x, _bay_size.y - 4.0)


func _add_label(text: String, position: Vector2, size: Vector2, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
