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
## Ticket 05 (ADR-0020's asset-contract follow-up) extends this with the
## Room interior assignment (resolve_room_interior()) and the anchor
## registry (resolve_anchor() plus the indexed lobby_queue/terrace_*
## resolvers below) without changing anything ticket 04 already answers.
## Bay/Build-Slot occupancy content (ticket 08) extends it further later.

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
		var interior := resolve_room_interior(room_type_id, room_name)
		var band_variant: String = "full" if interior["kind"] == "painted" else "tiled"
		var entry := _floor_entry("room", level, room_type_id, "Level %d — %s" % [level, room_name], band_variant, float(interior["height"]))
		entry["interior"] = interior
		out.append(entry)
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


## --- Room interior assignment (ticket 05) ---

const SHELL_DIR := "res://assets/hotel_shell/"

## Ticket 03 cut and named three real painted interiors *thematically*
## (jungle/ice/bamboo) before any Room type was assigned to them, so they
## can't follow the naming convention resolve_room_interior() otherwise
## uses (see below) -- this table is the one-time alias fixing that up.
## Chosen by theme against each type's tags in data/rooms.json: lagoon_room
## (warm/water) reads as the jungle band's tropical lagoon, ice_grotto
## (cold/water) as the ice band, roost_loft (high_perch/dry) as the bamboo
## band's aviary perches.
const ROOM_TYPE_INTERIOR_FILE := {
	"lagoon_room": {"file": "room_interior_jungle.png", "height": ROOM_FLOOR_HEIGHT},
	"ice_grotto": {"file": "room_interior_ice.png", "height": 131.0},
	"roost_loft": {"file": "room_interior_bamboo.png", "height": 158.0},
}

## Placeholder tint per un-painted Room type, so a floor without real art
## yet still reads as a specific kind of room rather than generic gray.
## Any Room type id not listed here -- including a future type this ticket
## never heard of -- falls back to DEFAULT_PLACEHOLDER_TINT, proving the
## contract's fallback rule holds generally, not just for these three.
const PLACEHOLDER_TINTS := {
	"cozy_nook": Color(0.55, 0.38, 0.25),
	"cavern_suite": Color(0.22, 0.2, 0.28),
	"tundra_hall": Color(0.75, 0.85, 0.92),
}
const DEFAULT_PLACEHOLDER_TINT := Color(0.33, 0.3, 0.28)


## Resolves a Room type's interior slot: {kind: "painted", file: String,
## height: float} or {kind: "placeholder", height: ROOM_FLOOR_HEIGHT,
## tint: Color, label: room_name}. Checked in order:
##  1. ROOM_TYPE_INTERIOR_FILE's one-time alias for the three types ticket
##     03 already painted under a non-conventional name.
##  2. The naming convention every OTHER Room type gets for free:
##     "room_interior_<room_type_id>.png" under SHELL_DIR. `probe_fn` (real
##     default: _probe_shell_file_height(), which checks the file exists on
##     disk and reads its real pixel height) resolves this -- injectable so
##     tests can exercise both branches without touching the filesystem.
##  3. The tinted, labelled placeholder fallback.
## This is *where* the contract's fallback rule lives: dropping a
## correctly-named, correctly-sized file into assets/hotel_shell/ for ANY
## of the six Room types -- including the three on the fallback today --
## flips it to "painted" with no code change, because branch 2 is a naming
## convention, not a closed table. The renderer (ui/hotel_world.gd) just
## load()s whatever file this returns and never itself checks whether one
## exists.
static func resolve_room_interior(room_type_id: String, room_name: String, probe_fn: Callable = Callable()) -> Dictionary:
	if ROOM_TYPE_INTERIOR_FILE.has(room_type_id):
		var asset: Dictionary = ROOM_TYPE_INTERIOR_FILE[room_type_id]
		return {"kind": "painted", "file": String(asset["file"]), "height": float(asset["height"])}

	var conventional_file := "room_interior_%s.png" % room_type_id
	var height = probe_fn.call(conventional_file) if probe_fn.is_valid() else _probe_shell_file_height(conventional_file)
	if height != null:
		return {"kind": "painted", "file": conventional_file, "height": float(height)}

	var tint: Color = PLACEHOLDER_TINTS.get(room_type_id, DEFAULT_PLACEHOLDER_TINT)
	return {"kind": "placeholder", "height": ROOM_FLOOR_HEIGHT, "tint": tint, "label": room_name}


## Real (non-test) implementation of resolve_room_interior()'s probe: null
## if `filename` doesn't exist under SHELL_DIR, else its real pixel height.
static func _probe_shell_file_height(filename: String):
	var path := SHELL_DIR + filename
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	return float(texture.get_height())


## --- Anchor registry (ticket 05) ---
##
## Named standing positions within a floor's band, in floor-local space:
## x=0 is the band's left edge (the same x-range every band kind shares --
## Reception's and Terrace's full-width painted bands are documented in
## docs/asset_contract.md as carrying their own frame columns and shaft
## baked in at the identical 0-71/71-168/168-501/501-572 offsets ticket 03
## cut the reusable Room-floor tiles from), and y=0 is that band's own top
## edge, growing downward to its height. resolve_anchor() and the indexed
## resolve_*_point() functions below are the only place a floor's anchors
## meet its placement: each adds that floor's own top_y (derived from
## floor_bottom_y(), same as _add_floor_band() already does) to translate
## a local anchor into a world position. The renderer calls these and
## derives no position of its own.

const SHAFT_CENTER_X := COLUMN_WIDTH + SHAFT_WIDTH / 2.0 # 119.5 -- every band's shaft sits at this x, so the elevator door is here on every floor kind
const INTERIOR_LEFT := COLUMN_WIDTH + SHAFT_WIDTH # 168.0 -- left edge of the 333px interior region every band kind shares
const BAY_WIDTH := INTERIOR_WIDTH / 2.0 # 166.5 -- the two Room bays split the interior evenly, meeting with no gap

const QUEUE_SPACING := 40.0

## Reception band (height LOBBY_HEIGHT): the front desk (Reception's
## post), the supply closet (Housekeeping's post, per the spec's "Stations
## become world posts"), and the staff nook (where an unassigned Staffer
## loiters) are each a single point; the lobby queue is a line, resolved
## per-index below rather than as a fixed set of points.
const FRONT_DESK_LOCAL := Vector2(INTERIOR_LEFT + 60.0, 120.0)
const SUPPLY_CLOSET_LOCAL := Vector2(INTERIOR_LEFT + 20.0, 40.0)
const STAFF_NOOK_LOCAL := Vector2(INTERIOR_LEFT + 100.0, 60.0)
const LOBBY_QUEUE_ORIGIN := Vector2(INTERIOR_LEFT + 180.0, 150.0)

## Terrace band (height TERRACE_HEIGHT): diner spots are a small grid of
## table positions; the entrance queue is a line, same shape as the lobby
## queue but its own anchor so the two never collide.
const TERRACE_ENTRANCE_QUEUE_ORIGIN := Vector2(INTERIOR_LEFT + 20.0, 150.0)
const TERRACE_DINER_GRID_ORIGIN := Vector2(INTERIOR_LEFT + 60.0, 50.0)
const TERRACE_DINER_GRID_SPACING := Vector2(120.0, 70.0)
const TERRACE_DINER_GRID_COLUMNS := 2


## Local-space rect for a Room floor's bay 0 (left) or bay 1 (right),
## spanning the floor's own full height -- so a shorter painted floor
## (e.g. ice_grotto's 131px band) gets correspondingly shorter bays.
static func room_bay_rect_local(bay_index: int, height: float) -> Rect2:
	return Rect2(Vector2(INTERIOR_LEFT + float(bay_index) * BAY_WIDTH, 0.0), Vector2(BAY_WIDTH, height))


## Every band kind's elevator door sits at the shaft's horizontal center,
## at that floor's own floor level (local y = height, its bottom edge) --
## consistent across Reception, Terrace, and every Room floor since all
## three share the same shaft x-range.
static func elevator_door_local(height: float) -> Vector2:
	return Vector2(SHAFT_CENTER_X, height)


static func lobby_queue_point_local(index: int) -> Vector2:
	return LOBBY_QUEUE_ORIGIN + Vector2(float(index) * QUEUE_SPACING, 0.0)


static func terrace_entrance_queue_point_local(index: int) -> Vector2:
	return TERRACE_ENTRANCE_QUEUE_ORIGIN + Vector2(float(index) * QUEUE_SPACING, 0.0)


static func terrace_diner_spot_local(index: int) -> Vector2:
	var col := index % TERRACE_DINER_GRID_COLUMNS
	var row := int(index / TERRACE_DINER_GRID_COLUMNS)
	return TERRACE_DINER_GRID_ORIGIN + Vector2(float(col) * TERRACE_DINER_GRID_SPACING.x, float(row) * TERRACE_DINER_GRID_SPACING.y)


## Named (non-indexed) anchors per band kind, in floor-local space. Returns
## null for a name the given kind doesn't carry (e.g. "front_desk" asked
## of a "room" floor, or "bay_left" asked of "reception") -- the registry
## is deliberately per-kind, not one flat global namespace.
static func _named_anchor_local(kind: String, name: String, height: float) -> Variant:
	if name == "elevator_door":
		return elevator_door_local(height)
	if kind == "room":
		if name == "bay_left":
			return room_bay_rect_local(0, height)
		if name == "bay_right":
			return room_bay_rect_local(1, height)
	elif kind == "reception":
		if name == "front_desk":
			return FRONT_DESK_LOCAL
		if name == "supply_closet":
			return SUPPLY_CLOSET_LOCAL
		if name == "staff_nook":
			return STAFF_NOOK_LOCAL
	return null


## Resolves a named anchor (see _named_anchor_local()) for floor index `i`
## within `floors_bottom_to_top` into a WORLD position: a Vector2 for a
## point anchor, or a Rect2 for a rect anchor (bay_left/bay_right). Returns
## null if `name` isn't part of that floor's band kind.
static func resolve_anchor(floors_bottom_to_top: Array, i: int, name: String) -> Variant:
	var f: Dictionary = floors_bottom_to_top[i]
	var height: float = float(f["height"])
	var top_y: float = _floor_top_y(floors_bottom_to_top, i)
	var local: Variant = _named_anchor_local(String(f["kind"]), name, height)
	if local == null:
		return null
	if local is Rect2:
		return Rect2(Vector2(local.position.x, top_y + local.position.y), local.size)
	return Vector2(local.x, top_y + local.y)


static func resolve_lobby_queue_point(floors_bottom_to_top: Array, i: int, index: int) -> Vector2:
	return _resolve_local_point(floors_bottom_to_top, i, lobby_queue_point_local(index))


static func resolve_terrace_entrance_queue_point(floors_bottom_to_top: Array, i: int, index: int) -> Vector2:
	return _resolve_local_point(floors_bottom_to_top, i, terrace_entrance_queue_point_local(index))


static func resolve_terrace_diner_spot(floors_bottom_to_top: Array, i: int, index: int) -> Vector2:
	return _resolve_local_point(floors_bottom_to_top, i, terrace_diner_spot_local(index))


static func _resolve_local_point(floors_bottom_to_top: Array, i: int, local: Vector2) -> Vector2:
	var top_y: float = _floor_top_y(floors_bottom_to_top, i)
	return Vector2(local.x, top_y + local.y)


## Shared by resolve_anchor() and _resolve_local_point() -- floor index
## `i`'s own top edge in world space, the one place a floor's placement
## meets its anchors.
static func _floor_top_y(floors_bottom_to_top: Array, i: int) -> float:
	return floor_bottom_y(floors_bottom_to_top, i) - float(floors_bottom_to_top[i]["height"])
