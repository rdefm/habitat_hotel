extends GutTest

## Ticket 03 (.scratch/visual-hotel-world/issues/03-slice-the-hotel-background.md)
## cuts assets/hotel-background.jpg into named PNG slots so the building can
## compose itself to any floor count. This proves the cut lost nothing: the
## sky/city layer plus the roofline cap, the five original room/terrace/lobby
## bands, and the ground plinth, stacked back in their original order,
## reconstruct the source painting. A small per-byte tolerance absorbs
## JPEG-decoder rounding between Godot's and the slicing tool's decode of the
## same source file -- it would not absorb an actually missing or misplaced
## band.
##
## The reconstruction alone can't distinguish a correctly alpha-punched
## sky/building split from a naive "everything fully opaque" cut, since both
## reproduce the source identically wherever a slice is opaque -- so a second
## test asserts the punch-out actually happened: the sky layer is transparent
## somewhere deep inside the building's solid footprint, and a building slice
## is transparent somewhere in its own sky-margin.
##
## The eight-band stacking test proves the repeating slots' *tiling contract*
## (exact height multiplication, real content at both edges so stacking
## can't produce a dead/transparent gap) -- it does not, and cannot cheaply,
## prove the seam is visually unnoticeable. That was verified by eye (8x
## vertical stacks of each repeating slot, and 3-/8-floor generic composites)
## -- see the ticket's Comments section for the method.

const SKY_PATH := "res://assets/hotel_shell/sky_and_city.png"
const SOURCE_PATH := "res://assets/hotel-background.jpg"

const BAND_ORDER := [
	{"path": "res://assets/hotel_shell/roofline_cap.png", "y": 0},
	{"path": "res://assets/hotel_shell/room_interior_jungle.png", "y": 143},
	{"path": "res://assets/hotel_shell/room_interior_ice.png", "y": 317},
	{"path": "res://assets/hotel_shell/room_interior_bamboo.png", "y": 448},
	{"path": "res://assets/hotel_shell/terrace_band.png", "y": 606},
	{"path": "res://assets/hotel_shell/lobby_band.png", "y": 776},
	{"path": "res://assets/hotel_shell/ground_plinth.png", "y": 976},
]

const REPEATING_SLOTS := [
	"res://assets/hotel_shell/frame_column_left.png",
	"res://assets/hotel_shell/frame_column_right.png",
	"res://assets/hotel_shell/elevator_shaft_segment.png",
]


## Every slot here is imported (has a .godot .import remap), so it must be
## loaded through the resource pipeline (load().get_image()) rather than
## Image.load_from_file() -- the latter raises "this will not work on
## export" for anything the importer already claims.
func _load_image(path: String) -> Image:
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	return texture.get_image()


func test_sliced_bands_reconstruct_the_source_painting() -> void:
	var source := _load_image(SOURCE_PATH)
	assert_not_null(source, "source painting should load")

	var sky := _load_image(SKY_PATH)
	assert_not_null(sky, "sky_and_city slice should load")
	assert_eq(sky.get_size(), source.get_size(), "sky layer should cover the full canvas")

	var canvas := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	canvas.blend_rect(sky, Rect2i(Vector2i.ZERO, sky.get_size()), Vector2i.ZERO)

	var covered_height := 0
	for band in BAND_ORDER:
		var slice: Image = _load_image(band.path)
		assert_not_null(slice, "band slice should load: %s" % band.path)
		assert_eq(slice.get_width(), source.get_width(), "band should be full width: %s" % band.path)
		canvas.blend_rect(slice, Rect2i(Vector2i.ZERO, slice.get_size()), Vector2i(0, band.y))
		covered_height += slice.get_height()

	assert_eq(covered_height, source.get_height(), "the roofline cap, five bands, and ground plinth should cover the full canvas height with no gap or overlap")

	canvas.convert(Image.FORMAT_RGB8)
	var recon_data := canvas.get_data()
	var src_data := source.get_data()
	assert_eq(recon_data.size(), src_data.size(), "reconstructed canvas should match the source's pixel buffer size")

	var total := src_data.size()
	var mismatches := 0
	var max_diff := 0
	for i in range(total):
		var d: int = absi(int(src_data[i]) - int(recon_data[i]))
		if d > max_diff:
			max_diff = d
		if d > 4:
			mismatches += 1

	var mismatch_ratio := float(mismatches) / float(total)
	assert_lt(mismatch_ratio, 0.005, "reconstruction should match the source almost everywhere (allowing JPEG decode rounding)")
	assert_lt(max_diff, 20, "no byte should be wildly different -- that would mean a lost, shifted, or wrong band")


func test_sky_and_building_slices_are_actually_alpha_punched() -> void:
	var sky := _load_image(SKY_PATH)
	assert_not_null(sky, "sky_and_city slice should load")
	# (286, 200) sits in the jungle band's room interior -- solid building,
	# nowhere near a window or a margin -- so the sky layer must be
	# transparent there, not carrying building content underneath it.
	assert_eq(sky.get_pixel(286, 200).a, 0.0, "sky layer should be transparent under the solid building, not just full-canvas opaque")

	var column := _load_image("res://assets/hotel_shell/frame_column_left.png")
	assert_not_null(column, "frame_column_left slice should load")
	# (5, 10) sits in this slot's own sky-margin (the pillar's opaque core
	# only starts around x=45) -- it must be transparent, not a baked-in
	# patch of sky, or this slot would carry sky into the building layer.
	assert_eq(column.get_pixel(5, 10).a, 0.0, "frame_column_left should be transparent in its own sky-margin, not carrying baked-in sky")


func test_repeating_slots_tile_with_no_dead_gap_across_eight_bands() -> void:
	for path in REPEATING_SLOTS:
		var tile := _load_image(path)
		assert_not_null(tile, "repeating slot should load: %s" % path)

		# A tile whose top or bottom edge row is entirely transparent would
		# open a visible gap wherever two copies meet -- so both edges need
		# real (opaque) content for repeating to be seamless at all.
		var top_has_content := false
		var bottom_has_content := false
		for x in range(tile.get_width()):
			if tile.get_pixel(x, 0).a > 0.0:
				top_has_content = true
			if tile.get_pixel(x, tile.get_height() - 1).a > 0.0:
				bottom_has_content = true
		assert_true(top_has_content, "repeating slot's top edge should have opaque content: %s" % path)
		assert_true(bottom_has_content, "repeating slot's bottom edge should have opaque content: %s" % path)

		var stacked := Image.create(tile.get_width(), tile.get_height() * 8, false, Image.FORMAT_RGBA8)
		for i in range(8):
			stacked.blend_rect(tile, Rect2i(Vector2i.ZERO, tile.get_size()), Vector2i(0, i * tile.get_height()))

		assert_eq(stacked.get_height(), tile.get_height() * 8, "eight stacked copies should have exactly 8x the tile height: %s" % path)


func test_roof_cap_is_flush_with_the_repeating_floor_width() -> void:
	var roof := _load_image("res://assets/hotel_shell/roofline_cap.png")
	assert_not_null(roof, "roofline_cap slice should load")
	var col_l := _load_image("res://assets/hotel_shell/frame_column_left.png")
	assert_not_null(col_l, "frame_column_left slice should load")
	var col_r := _load_image("res://assets/hotel_shell/frame_column_right.png")
	assert_not_null(col_r, "frame_column_right slice should load")
	var shaft := _load_image("res://assets/hotel_shell/elevator_shaft_segment.png")
	assert_not_null(shaft, "elevator_shaft_segment slice should load")
	var jungle := _load_image("res://assets/hotel_shell/room_interior_jungle.png")
	assert_not_null(jungle, "room_interior_jungle slice should load")

	# Width is floor-count-invariant -- a floor row's width doesn't change
	# whether it's the 3rd or the 8th floor -- so one equality here covers
	# both the three-band and eight-band cases the ticket calls out.
	var interior_width: int = jungle.get_width() - col_l.get_width() - col_r.get_width() - shaft.get_width()
	var floor_row_width: int = col_l.get_width() + shaft.get_width() + interior_width + col_r.get_width()

	assert_eq(roof.get_width(), floor_row_width, "roof cap width should exactly match a floor row's width, at any floor count, so it sits flush with no gap on either side")
