class_name GuestActor
extends Node2D

## One arriving Party MEMBER standing in the lobby queue (ticket 10,
## sim/building_layout.gd's lobby_guest_placements()) -- a Party of three is
## three GuestActors standing side by side, one per queue slot, each drawn
## from its own Species slot via CharacterSprite ("idle"), mirroring
## ui/diner_actor.gd's shape.
##
## Carries an always-visible mood face floating above its head, souring
## continuously as its own Party's Patience decays
## (BuildingLayout.resolve_mood_face_for_patience()) -- update_mood() is
## called every frame regardless of whether this actor was just
## (re)created, since Patience ticks down without the lobby's membership
## changing.
##
## ui/hotel_world.gd owns tap hit-testing against hit_rect() and the actual
## Needs-bubble open/close lifecycle a tap resolves to (ui/needs_bubble.gd);
## this class only draws itself and its own mood face.

const CharacterSprite = preload("res://ui/character_sprite.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")

const HIT_SIZE := Vector2(BuildingLayout.CHARACTER_FRAME_SIZE, BuildingLayout.CHARACTER_FRAME_SIZE)

## CharacterSprite's own origin is its footprint's bottom center (see that
## class's header) -- offsetting the mood face's origin straight up by the
## guest's own frame height plus a small gap puts the face's footprint just
## above the guest's head, with no overlap.
const MOOD_FACE_OFFSET := Vector2(0.0, -BuildingLayout.CHARACTER_FRAME_SIZE - 4.0)

var party_id: int = -1
var member_index: int = -1

var _sprite: CharacterSprite
var _mood_face: CharacterSprite


func configure(new_party_id: int, new_member_index: int, species_id: String) -> void:
	party_id = new_party_id
	member_index = new_member_index

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


## World-space hit rect for tap, matching CharacterSprite's own footprint
## convention -- this node's origin is the footprint's bottom center.
func hit_rect() -> Rect2:
	return Rect2(global_position - Vector2(HIT_SIZE.x / 2.0, HIT_SIZE.y), HIT_SIZE)
