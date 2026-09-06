class_name StafferActor
extends Node2D

## One Staffer standing at their current placement -- a Station post or the
## staff nook (ticket 07, sim/building_layout.gd's staffer_placements()).
## Wraps a CharacterSprite showing the Staffer's contract sprite/placeholder,
## idle at rest or working while a Kitchen Job keeps them at their own post
## (ticket 13 -- a Housekeeping Staffer's own working state renders on the
## separate travelling actor ui/hotel_world.gd's Job travel owns instead,
## since that Staffer has left this placement entirely). The "idle" state
## runs through ui/idle_animator.gd -- a plain still, with an occasional
## random idle-animation clip for whichever Staffer has one (Manny today,
## via his own alias) -- deactivated whenever "working" takes over so the
## timer can't fire mid-Job and stomp that state with an idle clip.
##
## ui/hotel_world.gd owns tap/drag hit-testing against hit_rect() below and
## the actual Sim.assign_staffer()/Sim.stack_staffer_on_*() calls a
## successful drop makes; this class only draws and reports its own
## footprint.

const CharacterSprite = preload("res://ui/character_sprite.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")
const IdleAnimator = preload("res://ui/idle_animator.gd")

const HIT_SIZE := Vector2(BuildingLayout.CHARACTER_FRAME_SIZE, BuildingLayout.CHARACTER_FRAME_SIZE)

var staffer_id: String = ""

var _sprite: CharacterSprite
var _idle_animator: IdleAnimator


func configure(new_staffer_id: String, state: String = "idle") -> void:
	staffer_id = new_staffer_id
	if _sprite == null:
		_sprite = CharacterSprite.new()
		add_child(_sprite)
		_idle_animator = IdleAnimator.new(_sprite)
		add_child(_idle_animator)

	if state == "idle":
		_idle_animator.configure("staffer", staffer_id)
	else:
		_idle_animator.deactivate()
		_sprite.configure(BuildingLayout.resolve_character_sprite("staffer", staffer_id, state))


## World-space hit rect for tap/drag, matching CharacterSprite's own
## footprint convention -- this node's origin is the footprint's bottom
## center.
func hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(HIT_SIZE.x / 2.0, HIT_SIZE.y), HIT_SIZE)
