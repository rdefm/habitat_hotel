class_name StaffMenu
extends VBoxContainer

## Stub for Chunk 2. Named staff with stats/traits, training, and firing
## arrive in Chunk 4. For now this just surfaces the flat placeholder wage
## cost that Chunk 1's economy already charges every night.

func _ready() -> void:
	custom_minimum_size = Vector2(420, 160)

	var wage := int(GameState.balance.get("costs", {}).get("staff_wage_per_day", 0))

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.text = (
		"Named staff (stats, traits, training, firing) arrive in Chunk 4.\n\n"
		+ "Right now your starting crew costs a flat %d cash/day, deducted "
		+ "every Night phase alongside room upkeep."
	) % wage
	add_child(label)
