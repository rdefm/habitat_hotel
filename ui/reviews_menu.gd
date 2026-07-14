class_name ReviewsMenu
extends VBoxContainer

## Reviews feed: every posted review so far, newest first, with the
## species' flavor line for a bit of personality.

func _ready() -> void:
	custom_minimum_size = Vector2(520, 420)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var history: Array = GameState.review_history
	if history.is_empty():
		list.add_child(_line("No reviews yet -- check back after your first guest checks out.", Color(1, 1, 1)))
		return

	for i in range(history.size() - 1, -1, -1):
		var review: Dictionary = history[i]
		var color: Color = {"positive": Color(0.5, 1, 0.5), "negative": Color(1, 0.5, 0.5)}.get(review["review"], Color(0.85, 0.85, 0.85))
		var guest_name: String = review.get("guest_name", "") if review.get("guest_name", "") else "Guest"
		list.add_child(_line("Day %d -- %s the %s (%s, %+d cash, satisfaction %.0f)" % [
			review["day"], guest_name, review["species_name"], review["review"], review["revenue"], review["satisfaction"],
		], color))
		list.add_child(_line("  \"%s\"" % review["flavor_line"], color))


func _line(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = color
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
