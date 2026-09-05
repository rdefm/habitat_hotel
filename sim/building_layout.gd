class_name BuildingLayout
extends RefCounted

## Pure derivation of the building's floor stack (ticket 04, ADR-0020):
## given a `rooms` catalog (GameState.rooms) and the current `stars`
## (GameState.stars), answers floor ordering, level numbering, each floor's
## shell band composition, and the camera's fit-all bounds. A RefCounted of
## static functions with no node or autoload dependencies, mirroring
## sim/match_hint.gd's shape -- ui/hotel_world.gd (the renderer) draws the
## shell from this module's output rather than deriving its own floor
## order, numbering, or bounds. (The renderer's Clock-driven sky tint is
## the one presentation detail genuinely outside this module's scope --
## see ui/hotel_world.gd's own header.)
##
## This is ticket 04's slice of the eventual full layout model; the anchor
## registry (ticket 05, per-band standing positions) and bay/build-slot
## content (ticket 08) extend it later without changing what's here.

## Pixel contract fixed by ticket 03's cut of assets/hotel-background.jpg
## (572x1024 -- see
## .scratch/visual-hotel-world/issues/03-slice-the-hotel-background_COMPLETED.md).
## The Reception and Terrace bands carry their own frame columns and
## elevator shaft baked in full-width ("full"). A Room floor without a
## painted interior of its own (every Room type, until ticket 05 assigns
## the three that get one) is composed instead ("tiled") from the reusable
## frame_column_left/right + elevator_shaft_segment tiles flanking a
## placeholder interior -- sized to the exact span ticket 03 cut those
## tiles from (the jungle band, 174px) so one copy per floor is already the
## right height, no repetition needed within a single floor.
const BUILDING_WIDTH := 572.0
const PLINTH_HEIGHT := 48.0
const ROOF_HEIGHT := 143.0
const LOBBY_HEIGHT := 200.0
const TERRACE_HEIGHT := 170.0
const ROOM_FLOOR_HEIGHT := 174.0

const COLUMN_WIDTH := 71.0
const SHAFT_WIDTH := 97.0
const INTERIOR_WIDTH := 333.0

const GROUND_FLOOR_LEVEL := 0
const TERRACE_LEVEL := 1


## Ordered bottom-to-top: Reception (Ground Floor, unnumbered), Terrace at
## Level 1, then one entry per unlocked Room type ascending by unlock.star
## (ties broken by array order in data/rooms.json -- see
## unlocked_room_type_ids_ascending()). Each entry:
## {kind: "reception"|"terrace"|"room", level: int, room_type_id: String
## ("" unless kind == "room"), sign_text: String, band_variant:
## "full"|"tiled", height: float}.
static func floors(rooms: Dictionary, stars: int) -> Array:
	var out: Array = []
	out.append(_floor_entry("reception", GROUND_FLOOR_LEVEL, "", "Reception", "full", LOBBY_HEIGHT))
	out.append(_floor_entry("terrace", TERRACE_LEVEL, "", "Level %d — Terrace" % TERRACE_LEVEL, "full", TERRACE_HEIGHT))

	var level := TERRACE_LEVEL + 1
	for room_type_id in unlocked_room_type_ids_ascending(rooms, stars):
		var room_name: String = String(rooms[room_type_id]["name"])
		out.append(_floor_entry("room", level, room_type_id, "Level %d — %s" % [level, room_name], "tiled", ROOM_FLOOR_HEIGHT))
		level += 1
	return out


static func _floor_entry(kind: String, level: int, room_type_id: String, sign_text: String, band_variant: String, height: float) -> Dictionary:
	return {
		"kind": kind,
		"level": level,
		"room_type_id": room_type_id,
		"sign_text": sign_text,
		"band_variant": band_variant,
		"height": height,
	}


## The Room type ids in `rooms` whose unlock.star is met by `stars`,
## ascending by unlock.star, ties broken by `rooms`' own iteration order --
## which is data/rooms.json's array order (see sim/data_loader.gd building
## GameState.rooms by inserting each JSON array entry in file order), NOT
## alphabetical by id.
static func unlocked_room_type_ids_ascending(rooms: Dictionary, stars: int) -> Array:
	var entries: Array = []
	var order := 0
	for room_type_id in rooms.keys():
		var star: int = int(rooms[room_type_id]["unlock"]["star"])
		if star <= stars:
			entries.append({"id": room_type_id, "star": star, "order": order})
		order += 1
	entries.sort_custom(func(a, b):
		if a["star"] != b["star"]:
			return a["star"] < b["star"]
		return a["order"] < b["order"]
	)
	var out: Array = []
	for entry in entries:
		out.append(entry["id"])
	return out


## The world Y (Godot: down is positive) of floor index `i`'s BOTTOM edge
## within `floors_bottom_to_top` (as returned by floors()). y = 0 is the
## ground plinth's bottom edge; the building extends upward (negative Y)
## from there. Purely additive over the floors below `i`, so appending a
## new floor at the end of the list never changes an earlier floor's
## bottom_y -- an unlock adds a floor on top without moving/renumbering
## anything below it. Passing floors_bottom_to_top.size() (one past the
## last floor) gives the topmost floor's TOP edge, i.e. where the roofline
## cap's bottom edge belongs.
static func floor_bottom_y(floors_bottom_to_top: Array, i: int) -> float:
	var y := -PLINTH_HEIGHT
	for j in range(i):
		y -= float(floors_bottom_to_top[j]["height"])
	return y


## Camera fit-all bounds framing the whole building -- ground plinth through
## roofline cap -- for the given floor stack. Recompute whenever floors()
## changes (a new floor unlocked); an earlier floor's position within the
## bounds never shifts, only the top edge moves further up.
static func fit_all_bounds(floors_bottom_to_top: Array) -> Rect2:
	var total_floor_height := 0.0
	for f in floors_bottom_to_top:
		total_floor_height += float(f["height"])
	var total_height: float = PLINTH_HEIGHT + total_floor_height + ROOF_HEIGHT
	return Rect2(Vector2(0.0, -total_height), Vector2(BUILDING_WIDTH, total_height))
