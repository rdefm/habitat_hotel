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
## No tap/drag behaviour: unlike a Staffer or a Room bay, a diner isn't a
## tap target yet -- mood faces and a Needs-bubble tap are ticket 10's job,
## mirrored here off the same lobby-guest work. This class only draws.

const CharacterSprite = preload("res://ui/character_sprite.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")

var species_id: String = ""

var _sprite: CharacterSprite


func configure(new_species_id: String) -> void:
	species_id = new_species_id
	if _sprite == null:
		_sprite = CharacterSprite.new()
		add_child(_sprite)
	_sprite.configure(BuildingLayout.resolve_character_sprite("guest", species_id, "idle"))
