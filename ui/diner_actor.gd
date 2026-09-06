class_name DinerActor
extends Node2D

## One Terrace diner standing at their current placement -- served at the
## pass or waiting in the entrance queue (ticket 09,
## sim/building_layout.gd's terrace_diner_placements()). Wraps a
## CharacterSprite showing the diner's Species sprite/placeholder at rest
## ("idle") -- the first live use of the "guest" character kind
## (BuildingLayout.resolve_character_sprite()), mirroring
## ui/staffer_actor.gd's shape for "staffer".
##
## Carries the same always-visible mood face a lobby GuestActor does
## (ticket 10, BuildingLayout.resolve_mood_face_for_patience()) -- "dining
## Patience reads the same way everywhere" (spec.md) -- kept updated every
## frame via update_mood() regardless of bucket, since a served entry's
## Patience is simply frozen rather than absent (Sim._decay_walkin_patience()
## skips decaying it, but the field is still there).
##
## No tap behaviour: unlike a Staffer, a Room bay, or a lobby guest, a diner
## isn't a tap target -- a Walk-in Diner has no "needs" array (the Match
## puzzle is a Room-booking Party's concern, not the Terrace's), so there's
## no Needs bubble for this class to pop. hit_rect() below exists only as a
## Staffer drag's Stacking drop target (ticket 13, ADR-0008) -- dropping a
## second Staffer onto a diner already being served stacks them onto that
## same dinner Job; this class itself only draws and reports its footprint.

const CharacterSprite = preload("res://ui/character_sprite.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")

const HIT_SIZE := Vector2(BuildingLayout.CHARACTER_FRAME_SIZE, BuildingLayout.CHARACTER_FRAME_SIZE)

## Mirrors ui/guest_actor.gd's MOOD_FACE_OFFSET exactly, so a diner's mood
## face sits at the identical relative position a lobby guest's does.
const MOOD_FACE_OFFSET := Vector2(0.0, -BuildingLayout.CHARACTER_FRAME_SIZE - 4.0)

var species_id: String = ""

var _sprite: CharacterSprite
var _mood_face: CharacterSprite


func configure(new_species_id: String) -> void:
	species_id = new_species_id
	if _sprite == null:
		_sprite = CharacterSprite.new()
		add_child(_sprite)
	_sprite.configure(BuildingLayout.resolve_character_sprite("guest", species_id, "idle"))

	if _mood_face == null:
		_mood_face = CharacterSprite.new()
		add_child(_mood_face)
		_mood_face.position = MOOD_FACE_OFFSET


func update_mood(patience: float, patience_cfg: Dictionary) -> void:
	_mood_face.configure(BuildingLayout.resolve_mood_face_for_patience(patience, patience_cfg))


## World-space hit rect for a Staffer drag's Stacking drop, matching
## ui/staffer_actor.gd's own footprint convention -- this node's origin is
## the footprint's bottom center.
func hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(HIT_SIZE.x / 2.0, HIT_SIZE.y), HIT_SIZE)
