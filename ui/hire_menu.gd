class_name HireMenu
extends VBoxContainer

## Stub for Chunk 2. The real weekly hire pool (named candidates, traits,
## quality scaling with stars) arrives in Chunk 4.

func _ready() -> void:
	custom_minimum_size = Vector2(420, 160)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.text = (
		"The weekly hire pool isn't open yet -- named candidates, traits, and "
		+ "quality scaling with your star level arrive in Chunk 4.\n\n"
		+ "For now, your starting staff are covered by a flat daily wage "
		+ "(see the Roster menu)."
	)
	add_child(label)
