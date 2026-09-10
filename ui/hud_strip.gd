class_name HudStrip
extends Control

## The HUD strip (ticket 14, ADR-0020): four vitals pills -- Cash, Hearts, a
## Star pill with Reputation rendered as its own fill, and a day/season chip
## -- plus a gear button opening a small popover for Pause/1x/2x, so those
## controls stay reachable without cluttering the strip itself (spec.md
## story 54). Replaces main_screen.gd's old plain-Label top bar; pinned to
## the top of the screen as a Control in the same HUD CanvasLayer as the
## rest of the chrome, above hotel_world.gd's Node2D world, so its Camera2D
## never transforms this strip (ticket 04's HUD-layer split). Reads
## GameState/Clock directly, same surface the retired top bar already read
## -- no new GameState/Sim call, this is presentation only.
##
## The gear popover is a bespoke child of this strip, not a PopupHost popup
## (ADR-0011) like every other small popup in this game: PopupHost's
## open_popup()/close_popup() unconditionally pause/resume the Clock, which
## would fight the very buttons this popover offers -- pressing "Pause"
## inside it, then closing it, would immediately un-pause again. So it never
## touches Clock.set_paused() itself except via those three buttons' own
## calls, exactly as the old top bar's buttons did.

const BuildingLayout = preload("res://sim/building_layout.gd")

## Fixed footprint, not measured after layout -- main_screen.gd hands this
## straight to HotelWorld.hud_top_margin before the world's first
## ease_to_fit_all() runs, so the two need to agree on a number up front
## rather than round-tripping through a post-layout minimum-size query.
const HEIGHT := 56.0

const BACKING_COLOR := Color(0, 0, 0, 0.55)
const STRIP_PADDING := 10.0
const PILL_SEPARATION := 8.0

const REPUTATION_TRACK_COLOR := Color(1, 1, 1, 0.18)
const REPUTATION_FILL_COLOR := Color(1.0, 0.84, 0.2, 0.9)

const CASH_NEGATIVE_COLOR := Color(1, 0.55, 0.55)
const CASH_POSITIVE_COLOR := Color(1, 1, 1)

const GEAR_POPOVER_COLOR := Color(0.12, 0.12, 0.15, 0.95)

var _cash_value: Label
var _hearts_value: Label
var _star_value: Label
var _reputation_fill: ProgressBar
var _day_value: Label

var _fit_all_button: Button
var _gear_popover: PanelContainer


func _ready() -> void:
	## set_anchors_preset(TOP_WIDE) alone left this root Control's own
	## resolved width at 0 under a CanvasLayer parent (confirmed via
	## get_ui_elements against a live run: every pill and the gear popover
	## still rendered, but only because HBoxContainer/PanelContainer fall
	## back to their own minimum size when their allocated rect is
	## degenerate -- the gear popover, anchored PRESET_TOP_RIGHT relative to
	## *this* Control, computed its anchor point off that phantom zero width
	## and landed off-screen at x=-89). Setting every offset explicitly,
	## rather than trusting the preset's own snapshot-based defaults, pins
	## an actual full-viewport-width, fixed-HEIGHT-tall rect.
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	offset_left = 0.0
	offset_right = 0.0
	offset_top = 0.0
	offset_bottom = HEIGHT

	var backing := ColorRect.new()
	backing.color = BACKING_COLOR
	backing.set_anchors_preset(Control.PRESET_FULL_RECT)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backing)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", PILL_SEPARATION)
	row.offset_left = STRIP_PADDING
	row.offset_right = -STRIP_PADDING
	row.offset_top = STRIP_PADDING
	row.offset_bottom = -STRIP_PADDING
	add_child(row)

	var cash := _make_value_pill("cash")
	_cash_value = cash["value"]
	row.add_child(cash["pill"])

	var hearts := _make_value_pill("hearts")
	_hearts_value = hearts["value"]
	row.add_child(hearts["pill"])

	row.add_child(_make_star_pill())

	var day := _make_value_pill("calendar")
	_day_value = day["value"]
	row.add_child(day["pill"])

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	## Ticket 04's "ease back to fit-all" camera control -- unlike Pause/1x/2x,
	## spec.md doesn't send this one behind the gear (story 4 wants it a
	## single reachable control), so it's its own strip button. Hidden until
	## configure() is called with a valid callback -- main_screen.gd does so
	## unconditionally now that ui/hotel_world.gd is the game's only play
	## surface (ticket 17).
	_fit_all_button = Button.new()
	_fit_all_button.text = "Fit All"
	_fit_all_button.visible = false
	row.add_child(_fit_all_button)

	row.add_child(_make_gear_button())

	_build_gear_popover()
	refresh()


## Wires the "Fit All" button to `fit_all_callback` and reveals it -- called
## by main_screen.gd once, right after instantiation, only when the Node2D
## world is mounted. Left unconfigured (never called), the button stays
## hidden, e.g. under the retired Control-based view where there's no camera
## to reset.
func configure(fit_all_callback: Callable) -> void:
	_fit_all_button.visible = true
	_fit_all_button.pressed.connect(fit_all_callback)


func refresh() -> void:
	_cash_value.text = "%d" % GameState.cash
	_cash_value.add_theme_color_override("font_color", CASH_NEGATIVE_COLOR if GameState.cash < 0 else CASH_POSITIVE_COLOR)
	_hearts_value.text = "%d" % GameState.hearts
	_star_value.text = "%d Star" % GameState.stars
	_reputation_fill.value = clampi(GameState.reputation, 0, 100)
	_day_value.text = "Day %d\n%s" % [GameState.day, GameState.season.capitalize()]


## --- Pills ---
##
## Every pill's background is BuildingLayout.resolve_hud_pill()'s own
## sprite-or-placeholder (the asset contract's HUD pill slot, ticket 05/06 --
## this is the first ticket to render it live), with a live value Label on
## top: a static pill image can carry an icon but never a live number, so
## the dynamic content is always this file's own overlay, sprite or not.

func _make_value_pill(pill_id: String) -> Dictionary:
	var shell := _make_pill_shell(pill_id)
	var value := _make_pill_label()
	(shell["pill"] as Control).add_child(value)
	return {"pill": shell["pill"], "value": value}


## The Star pill (spec.md: "a Star pill with Reputation rendered as its
## fill... Reputation being progress within a Star"; CONTEXT.md: "a 0-100
## meter within the current Star level") -- same shell as _make_value_pill(),
## plus a ProgressBar sandwiched between the background and the label whose
## fill IS Reputation, so there's no separate Reputation number anywhere in
## this strip.
func _make_star_pill() -> Control:
	var shell := _make_pill_shell("star")
	var pill: Control = shell["pill"]
	var corner_radius := int((shell["size"] as Vector2).y / 2.0)

	_reputation_fill = ProgressBar.new()
	_reputation_fill.min_value = 0
	_reputation_fill.max_value = 100
	_reputation_fill.show_percentage = false
	_reputation_fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	_reputation_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var track_style := StyleBoxFlat.new()
	track_style.bg_color = REPUTATION_TRACK_COLOR
	track_style.set_corner_radius_all(corner_radius)
	_reputation_fill.add_theme_stylebox_override("background", track_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = REPUTATION_FILL_COLOR
	fill_style.set_corner_radius_all(corner_radius)
	_reputation_fill.add_theme_stylebox_override("fill", fill_style)

	pill.add_child(_reputation_fill)

	_star_value = _make_pill_label()
	pill.add_child(_star_value)

	return pill


## Shared by _make_value_pill()/_make_star_pill(): resolve the pill id to its
## sprite-or-placeholder background and wrap it in a correctly-sized shell
## Control, before either caller layers its own value Label (and, for the
## Star pill, the Reputation ProgressBar) on top.
func _make_pill_shell(pill_id: String) -> Dictionary:
	var resolved: Dictionary = BuildingLayout.resolve_hud_pill(pill_id)
	var size: Vector2 = resolved["size"]

	var pill := Control.new()
	pill.custom_minimum_size = size
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pill.add_child(_make_pill_background(resolved, size))

	return {"pill": pill, "size": size}


func _make_pill_background(resolved: Dictionary, size: Vector2) -> Control:
	if resolved["kind"] == "sprite":
		var tex := TextureRect.new()
		tex.texture = load(String(resolved["file"]))
		tex.stretch_mode = TextureRect.STRETCH_SCALE
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return tex

	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = resolved["tint"]
	style.set_corner_radius_all(int(size.y / 2.0))
	bg.add_theme_stylebox_override("panel", style)
	return bg


func _make_pill_label() -> Label:
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


## --- The gear and its Pause/1x/2x popover ---

func _make_gear_button() -> Button:
	var gear := Button.new()
	gear.text = "..."
	gear.custom_minimum_size = Vector2(36, 36)
	gear.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gear.pressed.connect(_toggle_gear_popover)
	return gear


func _build_gear_popover() -> void:
	_gear_popover = PanelContainer.new()
	_gear_popover.visible = false
	_gear_popover.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_gear_popover.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_gear_popover.position = Vector2(-STRIP_PADDING, HEIGHT + 4.0)

	var style := StyleBoxFlat.new()
	style.bg_color = GEAR_POPOVER_COLOR
	style.set_corner_radius_all(10)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_gear_popover.add_theme_stylebox_override("panel", style)
	add_child(_gear_popover)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_gear_popover.add_child(column)

	column.add_child(_make_gear_option("Pause", func(): Clock.set_paused(true)))
	column.add_child(_make_gear_option("1x", func():
		Clock.set_paused(false)
		Clock.set_speed(1.0)
	))
	column.add_child(_make_gear_option("2x", func():
		Clock.set_paused(false)
		Clock.set_speed(2.0)
	))


func _make_gear_option(option_text: String, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = option_text
	btn.pressed.connect(func():
		action.call()
		_gear_popover.visible = false
	)
	return btn


func _toggle_gear_popover() -> void:
	_gear_popover.visible = not _gear_popover.visible
