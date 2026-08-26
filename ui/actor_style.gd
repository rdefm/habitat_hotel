class_name ActorStyle
extends RefCounted

## Shared "plain colored shape" look for actor tokens (ADR-0015/ADR-0016:
## guests/Staffers render as plain shapes, not themed Button chrome). A
## flat, softly-rounded StyleBoxFlat replaces the engine's default bevelled
## Button panel on every state (normal/hover/pressed/focus) so a token's
## modulate tint (Patience tier, selection highlight, etc.) reads as a solid
## standing body instead of a UI button. Shared by ui/reception_panel.gd's
## guest actors and ui/station_panel.gd's Staffer actors so both read as the
## same kind of token.

static func flat_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(1, 1, 1)
	box.corner_radius_top_left = 10
	box.corner_radius_top_right = 10
	box.corner_radius_bottom_left = 10
	box.corner_radius_bottom_right = 10
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box
