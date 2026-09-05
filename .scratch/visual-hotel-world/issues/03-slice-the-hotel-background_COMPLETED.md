# 03 — Slice the hotel background into contract slots

**What to build:** `assets/hotel-background.jpg` is a single fixed painting of a five-band hotel. The game needs a building that grows to eight bands (Ground Floor, Terrace at Level 1, and up to six Room floors), so the painting is cut into parts that compose.

Cut it into named PNG slots — lossless, because JPEG ringing on pixel art is visible at nearest-neighbour zoom. The parts are: the night sky and city as its own layer behind everything; the ground plinth and pavement; one interior band per Room type the painting supplies (the jungle, ice and bamboo bands); the Terrace band (the kitchen/bar pass — its redraw to a table-service bistro is later work, this ticket takes it as drawn); the lobby band; the framed column with planters that repeats once per floor; the elevator shaft segment that repeats once per floor; and the roofline with its marquee sign, which caps whatever the top floor happens to be.

The repeating parts are the load-bearing ones: the frame column and the shaft segment must tile vertically with no seam, at any floor count, and the roof cap must sit flush on the topmost band. Verify that by stacking eight bands, not three.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [x] Every slot is a lossless PNG imported with nearest-neighbour filtering
- [x] The sky and city are a separate layer with no building pixels baked into it, and the building slices carry no sky
- [x] The frame column and elevator shaft segments tile vertically with no visible seam across an eight-band stack
- [x] The roof cap sits flush on the top band at three bands and at eight
- [x] The three Room-type interior bands, the Terrace band, the lobby band and the ground plinth are separate files
- [x] A test composition of the original five bands is pixel-comparable to the source painting, proving nothing was lost in the cut

## Comments

Cut `assets/hotel-background.jpg` (572x1024) into `assets/hotel_shell/`:

- `sky_and_city.png` — full canvas, opaque only where classified sky/city, transparent under the building silhouette.
- `roofline_cap.png` (y 0-143), `room_interior_jungle.png` (143-317), `room_interior_ice.png` (317-448), `room_interior_bamboo.png` (448-606), `terrace_band.png` (606-776), `lobby_band.png` (776-976), `ground_plinth.png` (976-1024) — full-width (572px) crops, covering the canvas height with no gap or overlap.
- `frame_column_left.png` / `frame_column_right.png` (71px) and `elevator_shaft_segment.png` (97px) — cut once from the jungle band's span and meant to be reused (tiled) for every floor beyond the five the painting actually drew, not just the jungle floor. The real jungle/ice/bamboo/terrace/lobby bands above keep their own pillar and shaft art baked in full-width; these three exist so a placeholder-interior floor (the three unpainted Room types, or any floor past the original five) still gets a real column and shaft on its sides.

Classification (sky vs. building) is a chroma-key heuristic (blue-dominant or star-bright pixels = sky), with small isolated blobs cleaned up on both sides from the *same* mask so the two layers stay exact complements — this is what makes the reconstruction bit-exact rather than approximate. The ground plinth is the one exception: pavement shadow reads as "sky" under the heuristic (cool, dark tones), so it's kept fully opaque rather than chroma-keyed — there's no real sky gap in solid pavement to punch out.

Room-type/terrace/lobby margin columns (x<71, x>501) are chroma-keyed too (real sky/balcony-gap territory); the rest of each band's width is forced fully opaque so the ice room's blue interior can't be mistaken for sky.

Verification: `tests/test_hotel_background_slices.gd` (GUT) — composites sky_and_city + the seven bands and diffs against the source (bit-exact in practice; tolerance only guards against cross-decoder rounding), asserts the three repeating/roof-cap width relationships. Manual visual check (8x vertical stack of both frame columns and the shaft, and 3-/8-floor generic composites) confirmed no seams and a flush roof cap — see this comment for the method, not a checked-in fixture.

Project-wide `rendering/textures/canvas_textures/default_texture_filter` set to Nearest (0) in `project.godot` so every texture, these included, imports/renders pixelated by default — matches the rest of this pixel-art project rather than needing a per-file override.

Next (ticket 05) will need to pick the anchor/footprint math from the x-boundaries above: column 0-71, shaft 71-168, interior 168-501, column 501-572 (of a 572-wide floor row).
