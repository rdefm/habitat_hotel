class_name NeedsBubble
extends Node2D

## The bubble of Tag icons popped by tapping a waiting lobby guest (ticket
## 10) -- the Match puzzle's Needs shown against icons
## (BuildingLayout.resolve_tag_icon()) rather than a text card. One icon per
## tag in the tapped guest's Party's own "needs" array (Sim.pending_party()),
## laid out left to right and centered above the anchor position this node
## is placed at.
##
## ui/hotel_world.gd owns open/close lifecycle -- one bubble at a time,
## closed by tapping the same guest again or tapping elsewhere; this class
## only lays out and draws whatever needs it's configured with.

const CharacterSprite = preload("res://ui/character_sprite.gd")
const BuildingLayout = preload("res://sim/building_layout.gd")

const ICON_SPACING := 28.0
const PADDING := 6.0

## How far above this node's own origin (the anchor ui/hotel_world.gd
## positions it at, e.g. a guest's mood face) the bubble's bottom edge
## sits -- a small gap so the bubble never overlaps the mood face it's
## popped above.
const ANCHOR_GAP := 6.0


func configure(needs: Array) -> void:
	for child in get_children():
		child.queue_free()

	var icon_size: float = BuildingLayout.TAG_ICON_SIZE
	var content_width: float = float(needs.size()) * ICON_SPACING - (ICON_SPACING - icon_size) if not needs.is_empty() else icon_size
	var height: float = icon_size + PADDING * 2.0
	var width: float = content_width + PADDING * 2.0

	var background := ColorRect.new()
	background.color = Color(0, 0, 0, 0.7)
	background.size = Vector2(width, height)
	background.position = Vector2(-width / 2.0, -height - ANCHOR_GAP)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var start_x := -content_width / 2.0
	var icon_bottom_y := -ANCHOR_GAP - PADDING
	for i in range(needs.size()):
		var icon := CharacterSprite.new()
		add_child(icon)
		icon.configure(BuildingLayout.resolve_tag_icon(String(needs[i])))
		icon.position = Vector2(start_x + float(i) * ICON_SPACING + icon_size / 2.0, icon_bottom_y)
