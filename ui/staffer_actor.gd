class_name StafferActor
extends Node2D

## One Staffer standing at their current placement -- a Station post or the
## staff nook (ticket 07, sim/building_layout.gd's staffer_placements()).
## Wraps a CharacterSprite showing the Staffer's contract sprite/placeholder
## at rest ("idle" -- Manny has no idle sheet, so he renders his
## placeholder here like anyone else, per the contract's shared fallback;
## nothing yet drives a "working" state, that's tickets 08/13's Job travel).
##
## ui/hotel_world.gd owns tap/drag hit-testing against hit_rect() below and
## the actual Sim.assign_staffer() call a successful drop makes; this class
## only draws and reports its own footprint.

const CharacterSprite = preload("res://ui/character_sprite.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")

const HIT_SIZE := Vector2(BuildingLayout.CHARACTER_FRAME_SIZE, BuildingLayout.CHARACTER_FRAME_SIZE)

var staffer_id: String = ""

var _sprite: CharacterSprite


func configure(new_staffer_id: String) -> void:
	staffer_id = new_staffer_id
	if _sprite == null:
		_sprite = CharacterSprite.new()
		add_child(_sprite)
	_sprite.configure(BuildingLayout.resolve_character_sprite("staffer", staffer_id, "idle"))


## World-space hit rect for tap/drag, matching CharacterSprite's own
## footprint convention -- this node's origin is the footprint's bottom
## center.
func hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(HIT_SIZE.x / 2.0, HIT_SIZE.y), HIT_SIZE)
