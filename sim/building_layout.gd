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

const PatienceState = preload("res://sim/patience_state.gd")

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

## Kitchen's Station post (ticket 07) -- ADR-0010's "Kitchen is the Terrace
## pass" placed away from the diner grid and entrance queue lines above so
## none of the three collide.
const TERRACE_KITCHEN_PASS_LOCAL := Vector2(INTERIOR_LEFT + 292.0, 30.0)

## Tap target for the Terrace's signage (ticket 09, ADR-0010's "tap the
## structure" gesture) -- a generous rect over the floor sign's own top-left
## corner (see _add_floor_sign()'s Label position), well past the sign
## text's own bounds so the gesture is forgiving, mirroring
## ui/hotel_world.gd's STATION_POST_HIT_SIZE being larger than a Station
## prop's render footprint. Sits over the frame column/shaft region rather
## than the interior -- harmless, since neither is a tap target of its own
## on the Terrace band.
const TERRACE_SIGNAGE_RECT_LOCAL := Rect2(Vector2(0.0, 0.0), Vector2(180.0, 36.0))


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
	elif kind == "terrace":
		if name == "kitchen_pass":
			return TERRACE_KITCHEN_PASS_LOCAL
		if name == "signage":
			return TERRACE_SIGNAGE_RECT_LOCAL
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


## --- Room bays, Build Slots, and door plates (ticket 08) ---
##
## A Room floor always has exactly ROOM_BAY_COUNT bays (bay_left/bay_right,
## the anchor registry above) -- and, per data/rooms.json, every Room
## type's max_instances also happens to equal that count today, but
## room_bay_states() takes built_count/allow_build as plain values rather
## than reading GameState itself (this module stays a RefCounted of pure
## functions, no autoload dependencies, matching floors()'s own shape) so
## it degrades sensibly even if a future Room type's cap were ever lower
## than ROOM_BAY_COUNT.
const ROOM_BAY_COUNT := 2

## Per-bay states, left to right: bay 0 (bay_left) is index 0 of the
## returned Array, bay 1 (bay_right) is index 1. Built instances fill bays
## in ascending instance_id order first; the next bay after those becomes a
## Build Slot only if `allow_build` (the caller's GameState.can_build_more()
## result) says the Floor is still under its instance cap -- AT MOST ONE
## Build Slot bay per floor, even if more than one bay remains open,
## mirroring the old Control grid's single trailing "(build)" cell. Any bay
## past that (there is no second Build Slot) is an empty, unbuildable
## shell. Each entry is {state: "built"|"build_slot"|"empty", instance_id:
## int} -- instance_id is only meaningful for "built" (-1 otherwise).
static func room_bay_states(built_count: int, allow_build: bool) -> Array:
	var out: Array = []
	var build_slot_placed := false
	for bay_index in range(ROOM_BAY_COUNT):
		if bay_index < built_count:
			out.append({"state": "built", "instance_id": bay_index})
		elif not build_slot_placed and allow_build:
			out.append({"state": "build_slot", "instance_id": -1})
			build_slot_placed = true
		else:
			out.append({"state": "empty", "instance_id": -1})
	return out


## The per-bay visual state a built Room's bay draws, derived from a
## GameState.hotel_rooms entry's own fields -- occupancy, the cleaning
## flag, and purchased upgrades -- rather than anything this module tracks
## itself. `dirty` mirrors the old Control grid's rule (ui/hotel_panel.gd's
## retired _make_cell()): mess only shows on a currently-UNoccupied Room
## that still needs cleaning, since an occupied Room's guest is the visible
## state, not its housekeeping backlog.
static func room_bay_visual_state(room: Dictionary) -> Dictionary:
	var occupied: bool = room.get("occupant") != null
	return {
		"occupied": occupied,
		"dirty": not occupied and bool(room.get("needs_cleaning", false)),
		"upgrade_ids": (room.get("upgrades", []) as Array).duplicate(),
	}


## A built Room's door-plate number, derived purely from its Floor's level
## and which bay it sits in -- "so a toast or a review connects to the Room
## it came from" (ticket 08) without needing a separate stored field on the
## room instance. Bay 0 gets the lower number: Level 2's two Rooms are #201
## and #202, Level 3's are #301/#302, and so on -- an ordinary hotel
## floor/room-index numbering scheme.
static func room_number(level: int, bay_index: int) -> int:
	return level * 100 + bay_index + 1


## --- Room bay props (ticket 08) ---
##
## Same open-convention-else-placeholder shape as the single-frame slots
## below (resolve_tag_icon() et al.): a mess overlay for a dirty bay, and
## one prop per purchased upgrade id, keyed to the upgrade's own id so any
## Room type's upgrade catalog (data/rooms.json's per-type "upgrades"
## array) gets a slot for free with no per-type table to maintain.

const MESS_OVERLAY_SIZE := 40.0
const MESS_OVERLAY_DIR := "res://assets/effects/"

const UPGRADE_PROP_SIZE := 32.0
const UPGRADE_PROP_DIR := "res://assets/upgrades/"


static func resolve_mess_overlay(probe_fn: Callable = Callable()) -> Dictionary:
	return _resolve_static_icon(MESS_OVERLAY_DIR, "mess", Vector2(MESS_OVERLAY_SIZE, MESS_OVERLAY_SIZE), probe_fn)


static func resolve_upgrade_prop(upgrade_id: String, probe_fn: Callable = Callable()) -> Dictionary:
	return _resolve_static_icon(UPGRADE_PROP_DIR, upgrade_id, Vector2(UPGRADE_PROP_SIZE, UPGRADE_PROP_SIZE), probe_fn)


## --- Station posts and Staffer placement bucketing (ticket 07) ---
##
## Each of the three Stations (sim/station.gd's Station.IDS) is a physical
## post: Reception and Housekeeping's posts sit in the Reception band
## (front_desk/supply_closet, the anchor registry above); Kitchen's is the
## Terrace pass upstairs (ADR-0010 unchanged). Reception and Terrace are
## always floors_bottom_to_top's first two entries -- floors()'s own fixed
## ordering, never reordered by an unlock -- so the floor index each
## Station's post lives on is a hardcoded 0/1 below, not derived per call.

const STATION_POST_FLOOR_INDEX := {
	"reception": 0,
	"housekeeping": 0,
	"kitchen": 1,
}
const STATION_POST_ANCHOR_NAME := {
	"reception": "front_desk",
	"housekeeping": "supply_closet",
	"kitchen": "kitchen_pass",
}


## World position of station_id's physical post. Unknown station_id is a
## programming error -- every caller sources ids from Station.IDS -- left
## unguarded on purpose: the Dictionary lookups below log a script error and
## degrade to a garbage Vector2 rather than silently returning a plausible
## default, so a caller passing a bad id is loud in the console instead of
## quietly misplacing a Staffer.
static func resolve_station_post_anchor(floors_bottom_to_top: Array, station_id: String) -> Vector2:
	var floor_index: int = int(STATION_POST_FLOOR_INDEX[station_id])
	var anchor_name: String = String(STATION_POST_ANCHOR_NAME[station_id])
	return resolve_anchor(floors_bottom_to_top, floor_index, anchor_name)


## Where every Staffer stands: at their Station's post (bucket
## "post:<station_id>") if assigned, or the staff nook (bucket "nook") if
## not -- ADR-0005/CONTEXT.md's Staff Pool. More than one Staffer can share
## a post or the nook at once (a Station holds a list, not a single slot),
## so each bucket's members are stacked side by side off
## STAFFER_STACK_OFFSET by a stable index.
const STAFFER_STACK_OFFSET := Vector2(22.0, 0.0)

## Shared by staffer_bucket() (encode) and resolve_staffer_point() (decode)
## so the "post:<station_id>" bucket shape is defined once rather than the
## prefix and its length being duplicated at each end of the round-trip.
const POST_BUCKET_PREFIX := "post:"


static func staffer_bucket(station_id: String) -> String:
	return POST_BUCKET_PREFIX + station_id if station_id != "" else "nook"


## Every known Staffer's placement -- {bucket: String, index: int} keyed by
## staffer_id. `stations` is GameState.stations (station_id -> Array of
## assigned staffer ids); `all_staffer_ids` is every known Staffer id
## (GameState.staffers.keys()) so an unassigned Staffer -- absent from every
## Station's list -- is found by elimination rather than needing its own
## registry. Deterministic: each bucket's members are sorted alphabetically
## before indices are assigned, so a redraw with unchanged staffing always
## renders in the same order.
static func staffer_placements(stations: Dictionary, all_staffer_ids: Array) -> Dictionary:
	var buckets: Dictionary = {}
	var assigned: Dictionary = {}
	for station_id in stations.keys():
		var ids: Array = (stations[station_id] as Array).duplicate()
		ids.sort()
		buckets[staffer_bucket(station_id)] = ids
		for staffer_id in ids:
			assigned[staffer_id] = true

	var nook_ids: Array = []
	for staffer_id in all_staffer_ids:
		if not assigned.has(staffer_id):
			nook_ids.append(staffer_id)
	nook_ids.sort()
	buckets["nook"] = nook_ids

	var out: Dictionary = {}
	for bucket in buckets.keys():
		var ids: Array = buckets[bucket]
		for i in range(ids.size()):
			out[ids[i]] = {"bucket": bucket, "index": i}
	return out


## World position for a Staffer's placement (as returned by
## staffer_placements() above): the bucket's single anchor point --
## resolve_station_post_anchor() for a "post:<id>" bucket, the staff nook's
## anchor for "nook" -- offset by STAFFER_STACK_OFFSET*index so multiple
## Staffers at the same post/nook stand side by side instead of
## overlapping.
static func resolve_staffer_point(floors_bottom_to_top: Array, placement: Dictionary) -> Vector2:
	var bucket: String = String(placement["bucket"])
	var index: int = int(placement["index"])
	var anchor: Vector2
	if bucket == "nook":
		anchor = resolve_anchor(floors_bottom_to_top, 0, "staff_nook")
	else:
		anchor = resolve_station_post_anchor(floors_bottom_to_top, bucket.substr(POST_BUCKET_PREFIX.length()))
	return anchor + STAFFER_STACK_OFFSET * float(index)


## --- Character and interface slots (ticket 06) ---
##
## The same fallback rule ticket 05 established for the building shell
## (missing asset -> placeholder of identical footprint, tinted and
## labelled, resolved here rather than probed by the renderer) applied to
## every character and interface slot: per-Species guest sprites,
## per-Staffer sprites, Tag icons, mood faces, Station post props, and HUD
## pills. docs/asset_contract.md documents the full contract; this is where
## it resolves.

## On-screen footprint AND canonical per-frame pixel size for a character
## sheet reached through the open naming convention below -- chosen to
## match both the 64x64 concept art already dropped under assets/ (pigeon,
## penguin, tortoise) and the frame_w/frame_h the sprite-generation tool
## that produced them already emits (see e.g. the metadata.json bundled in
## assets/pigeon1_walk.zip). A convention-slot sheet therefore renders at
## native size with no scaling. Manny's existing 256x256-frame sheets are a
## one-time alias (CHARACTER_SPRITE_FILE, below) scaled down to this same
## footprint at render time, exactly mirroring how ROOM_TYPE_INTERIOR_FILE
## sits alongside resolve_room_interior()'s open convention slot.
const CHARACTER_FRAME_SIZE := 64.0
const CHARACTER_DIR := "res://assets/characters/"

## Animation states named per kind (ticket 06): idle and walk are shared,
## the third is a context state whose name depends on what's standing in
## the slot -- "sleeping" for a Guest at Night, "working" for a Staffer at
## their post. There is no wander behaviour and no ambient behaviour
## scheduler; a slot is always in exactly one of these states.
const CHARACTER_STATES := {
	"guest": ["idle", "walk", "sleeping"],
	"staffer": ["idle", "walk", "working"],
}

## One-time alias for Manny's existing walk/sweep sheets (ticket 02),
## named and sized before this contract existed, so they can't follow the
## "<kind>s/<id>_<state>.png" convention every other character gets for
## free. No "idle" entry -- Manny has no idle sheet, so that state falls
## through to the placeholder like any other character's would. This is
## the ticket's own proof that a real asset loads through the exact same
## resolver as a placeholder does, no special-cased rendering path.
const CHARACTER_SPRITE_FILE := {
	"staffer": {
		"manny": {
			"walk": {"file": "res://assets/Manny-walk.png", "frame_width": 256.0, "frame_height": 256.0},
			"working": {"file": "res://assets/Manny-sweeping.png", "frame_width": 256.0, "frame_height": 256.0},
		},
	},
}


## Resolves a character slot (kind "guest"|"staffer", a Species/Staffer id,
## and one of CHARACTER_STATES[kind]) to either a real sprite sheet or the
## placeholder fallback. Checked in order, same shape as
## resolve_room_interior():
##  1. CHARACTER_SPRITE_FILE's one-time alias (Manny only today).
##  2. The open naming convention -- "assets/characters/<kind>s/<id>_
##     <state>.png" -- at the fixed CHARACTER_FRAME_SIZE per frame.
##     `probe_fn` (real default: _probe_character_sheet_size(), checking
##     the file exists and reading its real pixel size) resolves this;
##     injectable so tests don't touch the filesystem.
##  3. The tinted, labelled placeholder.
## Returns {kind: "sprite", file, frame_width, frame_height, size} or
## {kind: "placeholder", size, tint, label}. The renderer loads whatever
## "file" this hands it and slices it into frame_width x frame_height
## frames off the loaded texture's own real dimensions -- this function
## never itself counts frames.
static func resolve_character_sprite(kind: String, character_id: String, state: String, probe_fn: Callable = Callable()) -> Dictionary:
	var alias: Dictionary = CHARACTER_SPRITE_FILE.get(kind, {}).get(character_id, {}).get(state, {})
	if not alias.is_empty():
		return _character_sprite_result(String(alias["file"]), float(alias["frame_width"]), float(alias["frame_height"]))

	var conventional_path := "%s%ss/%s_%s.png" % [CHARACTER_DIR, kind, character_id, state]
	var sheet_size = probe_fn.call(conventional_path) if probe_fn.is_valid() else _probe_character_sheet_size(conventional_path)
	if sheet_size != null:
		return _character_sprite_result(conventional_path, CHARACTER_FRAME_SIZE, CHARACTER_FRAME_SIZE)

	return {
		"kind": "placeholder",
		"size": Vector2(CHARACTER_FRAME_SIZE, CHARACTER_FRAME_SIZE),
		"tint": placeholder_tint_for_id(character_id),
		"label": placeholder_label_for_id(character_id),
	}


static func _character_sprite_result(file: String, frame_width: float, frame_height: float) -> Dictionary:
	return {
		"kind": "sprite",
		"file": file,
		"frame_width": frame_width,
		"frame_height": frame_height,
		"size": Vector2(CHARACTER_FRAME_SIZE, CHARACTER_FRAME_SIZE),
	}


## Real (non-test) implementation of resolve_character_sprite()'s probe:
## null if `path` doesn't exist, else its real pixel size (Vector2) so the
## renderer can derive a dropped-in sheet's own column/row count rather
## than assuming one.
static func _probe_character_sheet_size(path: String):
	if not ResourceLoader.exists(path):
		return null
	var texture: Texture2D = load(path)
	if texture == null:
		return null
	return Vector2(texture.get_width(), texture.get_height())


## Deterministic hash-derived tint for any id this contract has never heard
## of -- same proof-of-generality resolve_room_interior()'s
## DEFAULT_PLACEHOLDER_TINT makes, but as a formula rather than a table, so
## it holds for all eight Species and every Staffer today without hand
## -picking colors, and for whatever gets added later with no code change.
static func placeholder_tint_for_id(id: String) -> Color:
	## A 360-bucket hue (one degree each) collides too readily across even a
	## handful of ids (confirmed empirically against the 8-Species roster) --
	## spreading across a million buckets instead makes a collision
	## practically impossible without hand-picking colors.
	var hue: float = float(absi(id.hash()) % 1000000) / 1000000.0
	return Color.from_hsv(hue, 0.55, 0.85)


## Short label such as a species abbreviation (ticket 06) -- deliberately
## temporary text standing in for a Guest's or Staffer's sprite until it
## lands, same as a Room's placeholder carries its name.
static func placeholder_label_for_id(id: String) -> String:
	return id.substr(0, mini(3, id.length())).to_upper()


## --- Tag icons, mood faces, Station props, HUD pills (ticket 06) ---
##
## Simpler single-frame slots -- no animation states -- sharing the same
## alias-free "open naming convention, else placeholder" shape as
## resolve_character_sprite()'s convention branch. None of these has a
## real asset yet, so every one exercises the fallback today; landing a
## correctly-sized file at its conventional path is all a future ticket
## needs to do.

const TAG_ICON_SIZE := 24.0
const TAG_ICON_DIR := "res://assets/tags/"

const MOOD_FACE_SIZE := 20.0
const MOOD_FACE_DIR := "res://assets/moods/"
## Mood tiers named after sim/patience_state.gd's PatienceState.tier()
## return values, not CONTEXT.md's "content" prose gloss -- this is the
## vocabulary the resolver is actually called with.
const MOOD_FACE_TIERS := ["calm", "impatient", "huffy"]

const STATION_PROP_SIZE := 40.0
const STATION_PROP_DIR := "res://assets/stations/"

const HUD_PILL_SIZE := Vector2(96.0, 28.0)
const HUD_PILL_DIR := "res://assets/hud/"
const HUD_PILL_IDS := ["cash", "hearts", "star", "calendar"]


static func resolve_tag_icon(tag_id: String, probe_fn: Callable = Callable()) -> Dictionary:
	return _resolve_static_icon(TAG_ICON_DIR, tag_id, Vector2(TAG_ICON_SIZE, TAG_ICON_SIZE), probe_fn)


static func resolve_mood_face(tier: String, probe_fn: Callable = Callable()) -> Dictionary:
	return _resolve_static_icon(MOOD_FACE_DIR, tier, Vector2(MOOD_FACE_SIZE, MOOD_FACE_SIZE), probe_fn)


## Patience VALUE -> mood-face resolution (ticket 10): the one seam that
## takes a waiting guest's raw Patience (a pending_arrivals Party's or a
## Terrace walkin_queue entry's own "patience" field) straight to a
## drawable mood face, so every mood-face-carrying actor sours continuously
## as that value decays rather than each caller re-deriving
## PatienceState.tier() itself. `patience_cfg` is whichever config block
## owns that Patience -- data/balance.json's "patience" for a lobby Party,
## "dining.walkin_patience" for a Terrace diner (PatienceState.tier()'s own
## contract) -- so the same resolver serves both queues correctly even
## though they decay against different start/threshold values.
static func resolve_mood_face_for_patience(patience: float, patience_cfg: Dictionary, probe_fn: Callable = Callable()) -> Dictionary:
	return resolve_mood_face(PatienceState.tier(patience, patience_cfg), probe_fn)


static func resolve_station_prop(station_id: String, probe_fn: Callable = Callable()) -> Dictionary:
	return _resolve_static_icon(STATION_PROP_DIR, station_id, Vector2(STATION_PROP_SIZE, STATION_PROP_SIZE), probe_fn)


static func resolve_hud_pill(pill_id: String, probe_fn: Callable = Callable()) -> Dictionary:
	return _resolve_static_icon(HUD_PILL_DIR, pill_id, HUD_PILL_SIZE, probe_fn)


## Shared by the four single-frame resolvers above: "<dir><id>.png", else
## the tinted labelled placeholder at the same footprint. `probe_fn` (real
## default: _probe_exists()) stands in for the filesystem check in tests.
static func _resolve_static_icon(dir: String, id: String, size: Vector2, probe_fn: Callable) -> Dictionary:
	var path := "%s%s.png" % [dir, id]
	var exists: bool = probe_fn.call(path) if probe_fn.is_valid() else _probe_exists(path)
	if exists:
		return {"kind": "sprite", "file": path, "size": size}
	return {"kind": "placeholder", "size": size, "tint": placeholder_tint_for_id(id), "label": placeholder_label_for_id(id)}


static func _probe_exists(path: String) -> bool:
	return ResourceLoader.exists(path)


## --- Terrace: signage tap target, and diner placement (ticket 09) ---
##
## The Terrace is always floors_bottom_to_top's second entry (index
## TERRACE_LEVEL), same fixed-index reasoning
## resolve_station_post_anchor() already relies on for Reception/Terrace's
## own posts -- so both resolvers below hardcode that index rather than
## searching for it.

## World-space tap target for the Terrace's signage -- ADR-0010's "tap the
## structure" gesture, opening the existing Terrace menu unchanged.
static func resolve_terrace_signage_rect(floors_bottom_to_top: Array) -> Rect2:
	return resolve_anchor(floors_bottom_to_top, TERRACE_LEVEL, "signage")


## Every Sim.walkin_queue entry (a Walk-in Diner or a Dining Party alike --
## both share that one queue, CONTEXT.md) lands in one of two buckets:
## "pass" if a Kitchen Staffer is actively serving it (its "id" appears as
## an "entry_id" among `dinner_jobs`' values -- Sim._dinner_jobs' own
## shape, staffer_id -> {entry_id, ticks_remaining}), so a busy dinner
## service reads as diners visibly seated along the pass; "queue" otherwise,
## still waiting at the Terrace entrance. Same shape as
## staffer_placements() -- deterministic, keyed by each entry's own "id" --
## except ordering follows walkin_queue's own insertion order within each
## bucket rather than an alphabetical sort, since (unlike a Staffer id)
## there's no natural sort key to prefer over arrival order.
static func terrace_diner_placements(walkin_queue: Array, dinner_jobs: Dictionary) -> Dictionary:
	var served_entry_ids: Dictionary = {}
	for job in dinner_jobs.values():
		served_entry_ids[int(job["entry_id"])] = true

	var out: Dictionary = {}
	var pass_index := 0
	var queue_index := 0
	for entry in walkin_queue:
		var entry_id: int = int(entry["id"])
		if served_entry_ids.has(entry_id):
			out[entry_id] = {"bucket": "pass", "index": pass_index}
			pass_index += 1
		else:
			out[entry_id] = {"bucket": "queue", "index": queue_index}
			queue_index += 1
	return out


## World position for a diner's placement (as returned by
## terrace_diner_placements() above): the diner grid for a "pass" bucket,
## the entrance queue line for a "queue" bucket -- mirrors
## resolve_staffer_point()'s bucket-to-anchor split.
static func resolve_terrace_diner_point(floors_bottom_to_top: Array, placement: Dictionary) -> Vector2:
	var bucket: String = String(placement["bucket"])
	var index: int = int(placement["index"])
	if bucket == "pass":
		return resolve_terrace_diner_spot(floors_bottom_to_top, TERRACE_LEVEL, index)
	return resolve_terrace_entrance_queue_point(floors_bottom_to_top, TERRACE_LEVEL, index)


## --- Lobby guests: mood faces and Needs bubbles (ticket 10) ---
##
## An arriving Party stands in the lobby as one character PER MEMBER -- a
## Party of three is three consecutive lobby_queue slots, not one actor
## carrying a "×3" caption -- so party size is seen rather than read
## (spec.md stories 13/14). There is no "pass"/"queue" bucket split here
## the way terrace_diner_placements() has one: every pending_arrivals Party
## is, by definition, still waiting to be seated, so this returns a flat
## ordered Array of member placements rather than a bucket Dictionary.

## Expands `pending_arrivals` (Sim.pending_arrivals' own order) into one
## entry per Party member: {party_id: int, member_index: int, queue_index:
## int}. A later Party's members always continue the queue after an
## earlier Party's, so a Party leaving (seated or walked away) simply
## shortens the queue rather than reshuffling anyone still in it.
static func lobby_guest_placements(pending_arrivals: Array) -> Array:
	var out: Array = []
	var queue_index := 0
	for party in pending_arrivals:
		var party_id: int = int(party["id"])
		var party_size: int = int(party["party_size"])
		for member_index in range(party_size):
			out.append({"party_id": party_id, "member_index": member_index, "queue_index": queue_index})
			queue_index += 1
	return out


## World position for a lobby guest's placement (as returned by
## lobby_guest_placements() above) -- the lobby_queue anchor at that
## member's own queue_index. Reception is always floors_bottom_to_top's
## first entry (GROUND_FLOOR_LEVEL == its own index), same fixed-index
## reasoning resolve_station_post_anchor() already relies on.
static func resolve_lobby_guest_point(floors_bottom_to_top: Array, queue_index: int) -> Vector2:
	return resolve_lobby_queue_point(floors_bottom_to_top, GROUND_FLOOR_LEVEL, queue_index)


## --- Match hints (ticket 11) ---
##
## Whether a built bay's Room glows for the Party currently selected by a
## lobby-guest tap or drag (ADR-0001/0009: "the seating decision made
## against the building itself") -- green if every Need is covered, amber
## for a seatable-but-mismatched Room, "none" (no glow) for anything that
## isn't a valid seating target at all. Not re-derived here: `hint_fn` (real
## default: Sim.match_hint(), the single authority per spec.md's "Match
## hints are not re-derived") is called for a real selection, same
## injectable-probe shape as resolve_room_interior()'s probe_fn elsewhere in
## this file -- tests pass a literal-returning Callable so this stays a
## RefCounted of pure functions with no autoload dependency of its own.
## selected_party_id == -1 (nothing tapped or picked up) always answers
## "none" with no call at all, since there's nothing to hint against.
static func room_bay_match_hint(selected_party_id: int, room_type_id: String, instance_id: int, hint_fn: Callable = Callable()) -> String:
	if selected_party_id == -1:
		return "none"
	return hint_fn.call(selected_party_id, room_type_id, instance_id) if hint_fn.is_valid() else Sim.match_hint(selected_party_id, room_type_id, instance_id)
