class_name RoomOccupantActor
extends Node2D

## One occupant guest standing at a fixed spot inside their Room's bay for
## the whole stay (ticket 12, sim/building_layout.gd's
## room_occupant_placements()) -- ui/hotel_world.gd's elevator journey owns
## the actor while a guest is still travelling to or from the Room; this
## class only draws the settled, arrived state. Wraps a CharacterSprite
## showing the guest's "idle" state by day and "sleeping" at Night (spec.md
## story 25), with a small "Zz" label standing in for a sleeping animation
## no asset carries yet -- disappears the moment a real "sleeping" sheet
## lands, same as every other placeholder-era label in this contract.

const CharacterSprite = preload("res://ui/character_sprite.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")

const ZZ_OFFSET := Vector2(6.0, -BuildingLayout.CHARACTER_FRAME_SIZE - 6.0)

var _sprite: CharacterSprite
var _zz: Label = null


func configure(species_id: String, sleeping: bool) -> void:
	if _sprite == null:
		_sprite = CharacterSprite.new()
		add_child(_sprite)
	_sprite.configure(BuildingLayout.resolve_character_sprite("guest", species_id, "sleeping" if sleeping else "idle"))

	if sleeping and _zz == null:
		_zz = Label.new()
		_zz.text = "Zz"
		_zz.position = ZZ_OFFSET
		_zz.add_theme_font_size_override("font_size", 14)
		_zz.add_theme_color_override("font_color", Color(1, 1, 1))
		_zz.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		_zz.add_theme_constant_override("shadow_offset_x", 1)
		_zz.add_theme_constant_override("shadow_offset_y", 1)
		_zz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_zz)
	elif not sleeping and _zz != null:
		_zz.queue_free()
		_zz = null
