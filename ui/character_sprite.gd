class_name CharacterSprite
extends Node2D

## Generic renderer for one resolved character/interface slot (ticket 06,
## sim/building_layout.gd's resolve_character_sprite() and the four
## single-frame resolvers). Contains no file-existence check of its own --
## it only load()s whatever "file" the resolved Dictionary hands it, or
## draws the placeholder Dictionary's tint/label, same fallback-rule split
## as ui/hotel_world.gd already draws the building shell with.
##
## Positioned so this node's own origin is the slot's footprint's bottom
## center -- "standing on" the anchor it's placed at, matching how the
## anchor registry treats e.g. elevator_door as a floor-level point rather
## than a band-top point.
##
## A resolved "sprite" dict carries "frame_width"/"frame_height" only when
## it came from resolve_character_sprite() (an animated sheet to slice); the
## four single-frame resolvers (tag icon, mood face, Station prop, HUD
## pill -- first rendered live by ticket 07's Station posts) hand back a
## "sprite" dict with no frame size at all, since there's only ever one
## frame to show. _add_sprite()/_add_static_sprite() are that split.

## `loop`/`on_finished` (ui/idle_animator.gd's own use) let a caller play a
## sheet once instead of looping forever, and get notified when it ends --
## every other caller leaves both at their loop-forever, no-callback
## defaults, unchanged from before this pair of params existed.
func configure(resolved: Dictionary, fps: float = 8.0, loop: bool = true, on_finished: Callable = Callable()) -> void:
	for child in get_children():
		child.queue_free()

	var size: Vector2 = resolved["size"]
	if resolved["kind"] != "sprite":
		_add_placeholder(resolved, size)
	elif resolved.has("frame_width"):
		_add_sprite(resolved, size, fps, loop, on_finished)
	else:
		_add_static_sprite(resolved, size)


func _add_sprite(resolved: Dictionary, size: Vector2, fps: float, loop: bool = true, on_finished: Callable = Callable()) -> void:
	var texture: Texture2D = load(String(resolved["file"]))
	var frame_width: float = float(resolved["frame_width"])
	var frame_height: float = float(resolved["frame_height"])
	var columns := maxi(1, int(texture.get_width() / frame_width))
	var rows := maxi(1, int(texture.get_height() / frame_height))

	var frames := SpriteFrames.new()
	frames.add_animation("play")
	frames.set_animation_loop("play", loop)
	frames.set_animation_speed("play", fps)
	for row in range(rows):
		for col in range(columns):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
			frames.add_frame("play", atlas)

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.centered = true
	sprite.position = Vector2(0, -size.y / 2.0)
	sprite.scale = Vector2(size.x / frame_width, size.y / frame_height)
	add_child(sprite)
	if not loop and on_finished.is_valid():
		sprite.animation_finished.connect(on_finished)
	sprite.play("play")


## A single static frame, no slicing -- the whole loaded texture scaled to
## the slot's contract footprint, same bottom-center origin convention as
## _add_sprite()'s AnimatedSprite2D.
func _add_static_sprite(resolved: Dictionary, size: Vector2) -> void:
	var texture: Texture2D = load(String(resolved["file"]))

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	sprite.position = Vector2(0, -size.y / 2.0)
	if texture != null and texture.get_width() > 0 and texture.get_height() > 0:
		sprite.scale = Vector2(size.x / texture.get_width(), size.y / texture.get_height())
	add_child(sprite)


## Sets the current sprite's horizontal facing -- true mirrors it to face
## left (ui/hotel_world.gd's elevator/Job-travel legs call this once per
## direction change, based on which way a leg's own start/end x differ, so
## a character visibly turns to face the way it's walking). No effect on a
## placeholder -- a plain tinted rect reads the same either way.
func set_flip_h(flipped: bool) -> void:
	for child in get_children():
		if child is AnimatedSprite2D or child is Sprite2D:
			child.flip_h = flipped


func _add_placeholder(resolved: Dictionary, size: Vector2) -> void:
	var rect := ColorRect.new()
	rect.color = resolved["tint"]
	rect.size = size
	rect.position = Vector2(-size.x / 2.0, -size.y)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

	var label := Label.new()
	label.text = String(resolved["label"])
	label.size = size
	label.position = rect.position
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
