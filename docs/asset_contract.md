# Asset contract

Where everything in the drawn hotel world (`ui/hotel_world.gd` and its successors) goes, so art can be produced against a fixed target and dropped in without touching code. Started by ticket 04 (ADR-0020), covering only the building-shell slots that ticket's renderer consumes; ticket 05 extends this document with the full anchor registry (standing positions within each band), the per-Room-type interior assignment and its placeholder fallback, and the Reception/Terrace bands' own anchors. Ticket 06 does the same for character slots.

**Fallback rule (states now, applies everywhere in this contract):** a missing asset renders a placeholder occupying the identical footprint, tinted and labelled. Resolution lives in the layout model (`sim/building_layout.gd`) — the renderer never checks whether a file exists on disk; it only `load()`s whatever path the model hands it. For the Room interior slot, resolution checks two things in order: `ROOM_TYPE_INTERIOR_FILE`, a one-time alias for the three Room types ticket 03 already painted under a non-conventional name (see below), and then a naming convention every *other* Room type gets for free — `room_interior_<room_type_id>.png` under `assets/hotel_shell/`. That means dropping a correctly-named, correctly-sized file into that folder for *any* Room type, including the three on the fallback today, flips it to painted with no code change: the convention is open-ended, not a closed table that needs a new row per type.

**Frame count and animation states (applies to every slot in this document):** every building-side slot is a single static frame with no animation states. Animation starts with ticket 06's character slots.

## Building shell (ticket 03's cut of `assets/hotel-background.jpg`, 572×1024)

All slots below are lossless PNGs under `assets/hotel_shell/`, imported with nearest-neighbour filtering (`rendering/textures/canvas_textures/default_texture_filter=0` in `project.godot`, project-wide). Building width is fixed at 572px regardless of floor count; only height grows.

| Slot | File | Size (px) | Anchor | Notes |
| --- | --- | --- | --- | --- |
| Sky and city | `sky_and_city.png` | full canvas | behind everything, own layer | Tinted per Clock day phase (`ui/hotel_world.gd`'s `SKY_COLORS`); not built from this file yet — ticket 04 renders a plain tinted `ColorRect` instead. Wiring the painted sky texture itself in is left to a later pass. |
| Ground plinth | `ground_plinth.png` | 572×48 | bottom-left corner at world y=0 (ground level) | Always present, beneath Reception. Never a Floor in `sim/building_layout.gd`'s `floors()` — it has no sign, no level number. |
| Lobby band (Reception) | `lobby_band.png` | 572×200 | top-left corner at the Ground Floor's top edge | Full-width painted band, own frame columns and shaft baked in. Reception's sign carries no level number. |
| Terrace band | `terrace_band.png` | 572×170 | top-left corner at Level 1's top edge | Full-width painted band, own frame columns and shaft baked in. Always Level 1, directly above Reception. |
| Frame column (left) | `frame_column_left.png` | 71×174 | top-left corner at a tiled Room floor's left edge | Cut from the jungle band's span; reused once per Room floor that has no painted interior of its own. |
| Frame column (right) | `frame_column_right.png` | 71×174 | top-left corner at x = 501 within a tiled Room floor | Same source cut, mirrored side. |
| Elevator shaft segment | `elevator_shaft_segment.png` | 97×174 | top-left corner at x = 71 within a tiled Room floor | Cut from the jungle band's span; tiles seamlessly floor-to-floor (verified by `tests/test_hotel_background_slices.gd`). |
| Roofline cap | `roofline_cap.png` | 572×143 | bottom edge flush with the topmost floor's top edge | Caps whatever Room type ends up on top; recomputed whenever a floor unlocks. |
| Room interior — Lagoon Room | `room_interior_jungle.png` | 572×174 | top-left corner at that floor's top edge | Painted (ticket 03's jungle band). Assigned to `lagoon_room` (`warm`/`water` reads as a tropical lagoon). |
| Room interior — Ice Grotto | `room_interior_ice.png` | 572×131 | top-left corner at that floor's top edge | Painted. Assigned to `ice_grotto` (`cold`/`water`) — its floor is 131px tall, shorter than the tiled generic 174px, so the floor stack's height for this one Room type comes from the art rather than `ROOM_FLOOR_HEIGHT`. |
| Room interior — Roost Loft | `room_interior_bamboo.png` | 572×158 | top-left corner at that floor's top edge | Painted. Assigned to `roost_loft` (`high_perch`/`dry` reads as a bamboo aviary) — 158px tall. |
| Room interior — placeholder | none (composed from the parts below) | 572×174 | interior region 168–501 within the tiled composition | Fallback for `cozy_nook`, `cavern_suite`, `tundra_hall`, and any Room type with neither a `ROOM_TYPE_INTERIOR_FILE` alias nor a matching `room_interior_<id>.png` on disk — tint and label come from `BuildingLayout.resolve_room_interior()`. |
| Room interior — convention slot | `room_interior_<room_type_id>.png` (e.g. `room_interior_cozy_nook.png`) | any (the dropped-in file's own pixel height) | top-left corner at that floor's top edge | **Open slot, not yet filled for any of the three fallback types.** The moment a correctly-sized file lands at this path for `cozy_nook`, `cavern_suite`, or `tundra_hall` (or any future Room type), `resolve_room_interior()` picks it up automatically — no code change, no new contract row needed. |

### Room interior assignment (ticket 05)

Three of the six Room types get one of the paintings above, aliased by `sim/building_layout.gd`'s `ROOM_TYPE_INTERIOR_FILE` since ticket 03 named them thematically before any Room type was assigned; the other three currently exercise the fallback, but — unlike the three aliases — are not stuck there: each already has an open convention slot (the row above) waiting for `room_interior_<id>.png` to exist. `PLACEHOLDER_TINTS` is the source of truth for the fallback tints; this table mirrors both.

| Room type id | Slot today | Height |
| --- | --- | --- |
| `lagoon_room` | `room_interior_jungle.png` (alias) | 174 |
| `ice_grotto` | `room_interior_ice.png` (alias) | 131 |
| `roost_loft` | `room_interior_bamboo.png` (alias) | 158 |
| `cozy_nook` | placeholder, tint `(0.55, 0.38, 0.25)`; open slot `room_interior_cozy_nook.png` | 174 |
| `cavern_suite` | placeholder, tint `(0.22, 0.2, 0.28)`; open slot `room_interior_cavern_suite.png` | 174 |
| `tundra_hall` | placeholder, tint `(0.75, 0.85, 0.92)`; open slot `room_interior_tundra_hall.png` | 174 |

Any Room type with no alias and no file at its convention slot (a `PLACEHOLDER_TINTS` miss too, e.g. a future addition this contract hasn't caught up with) falls back to `DEFAULT_PLACEHOLDER_TINT`, proving the fallback rule holds generally rather than only for these three.

### Tiled Room floor composition (unpainted Room types)

Left to right, within the floor's 572px width, for whichever Room type is on the fallback:

| Region | x range | Content |
| --- | --- | --- |
| Left frame column | 0–71 | `frame_column_left.png` |
| Elevator shaft | 71–168 | `elevator_shaft_segment.png` |
| Interior placeholder | 168–501 | `ColorRect` tinted per the table above, with the Room type's name as a centered label |
| Right frame column | 501–572 | `frame_column_right.png` |

Height is 174px (`sim/building_layout.gd`'s `ROOM_FLOOR_HEIGHT`) — the same span the frame column and shaft tiles were cut from, so one copy per floor is already the correct height with no repetition needed within a single floor. A painted Room floor (Lagoon Room, Ice Grotto, Roost Loft) uses its own height instead, per the table above; the frame columns and shaft aren't reused there since those bands, like Reception's and Terrace's, carry their own baked in.

### Floor signs

Every floor (Reception, Terrace, each Room floor) carries a sign reading its level number and name — `Level %d — %s` for Terrace/Room floors, `Reception` alone for the unnumbered Ground Floor. Rendered as a plain `Label` in the top-left corner of the floor's band; no painted sign asset exists yet.

## Anchor registry (ticket 05)

Named standing positions within a band, resolved by `sim/building_layout.gd`'s `resolve_anchor()` (named point/rect anchors) and its indexed `resolve_lobby_queue_point()` / `resolve_terrace_entrance_queue_point()` / `resolve_terrace_diner_spot()` functions (line/grid anchors). All positions below are floor-local: x=0 is the band's left edge, y=0 is the band's own top edge growing downward. Each resolver adds that floor's own top edge (world space) to translate a local anchor into a world position — the one place a floor's placement and its anchors meet. The renderer never derives a position of its own.

Every band shares the same x-range for its frame columns, elevator shaft and interior (0–71 / 71–168 / 168–501 / 501–572 of the 572px width) — Reception's and Terrace's full-width painted bands carry their own columns and shaft baked in at these same offsets, so the registry doesn't need a special case per band kind for x.

### Every floor (Reception, Terrace, every Room floor)

| Anchor | Local position | Notes |
| --- | --- | --- |
| `elevator_door` | `(119.5, height)` | Shaft's horizontal center, at that floor's own floor level (its bottom edge) — same x on every floor kind. |

### Reception band (height 200)

| Anchor | Local position | Notes |
| --- | --- | --- |
| `front_desk` | `(228, 120)` | Reception's Station post. |
| `supply_closet` | `(188, 40)` | Housekeeping's Station post (per the spec, this Station's post lives on the Ground Floor even though its Jobs happen at Room floors). |
| `staff_nook` | `(268, 60)` | Where an unassigned Staffer loiters. |
| `lobby_queue` (line) | `(348 + 40·n, 150)` for queue position `n = 0, 1, 2, …` | Arriving Parties waiting to be seated. |

### Terrace band (height 170)

| Anchor | Local position | Notes |
| --- | --- | --- |
| `diner_spots` (grid) | `(228 + 120·col, 50 + 70·row)`, `col = n % 2`, `row = n / 2` | Table positions for seated diners. |
| `entrance_queue` (line) | `(188 + 40·n, 150)` for `n = 0, 1, 2, …` | Waiting diners queueing at the Terrace entrance — a separate line from the lobby queue so the two never collide. |

### Room floor (any Room type, painted or placeholder)

| Anchor | Local position | Notes |
| --- | --- | --- |
| `bay_left` (rect) | `(168, 0)`–`(334.5, height)` | The floor's first Room bay. Height matches the floor's own (174 generic/painted-jungle, 131 for Ice Grotto, 158 for Roost Loft). |
| `bay_right` (rect) | `(334.5, 0)`–`(501, height)` | The floor's second Room bay — meets `bay_left` with no gap. |

## Character and interface slots (ticket 06)

Resolved by `sim/building_layout.gd`'s `resolve_character_sprite()` (guests and Staffers) and its four single-frame siblings — `resolve_tag_icon()`, `resolve_mood_face()`, `resolve_station_prop()`, `resolve_hud_pill()`. Same fallback rule as the building shell: a missing slot renders a placeholder of identical footprint, tinted (`BuildingLayout.placeholder_tint_for_id()`, a deterministic hash-of-id color so it holds for every current and future id with no table to maintain) and labelled with a short abbreviation (`placeholder_label_for_id()`, the id's first three characters, uppercased). Every one of these slots is empty today except Manny — every Species and every other Staffer, every Tag icon, every mood face, every Station prop, and every HUD pill renders its placeholder.

An anchor (the previous section) says *where* something stands; these slots say *what's drawn there*. Nothing here carries its own position.

### Guest and Staffer sprites

| Slot | File | Size (px) | Animation states |
| --- | --- | --- | --- |
| Guest (per Species, 8 total) | `assets/characters/guests/<species_id>_<state>.png` | 64×64 per frame, footprint 64×64 | `idle`, `walk`, `sleeping` |
| Staffer (per Staffer, 3 total) | `assets/characters/staffers/<staffer_id>_<state>.png` | 64×64 per frame, footprint 64×64 | `idle`, `walk`, `working` |

Frame count for a convention-slot sheet is never fixed — it's the dropped-in file's own width/height, each divided by 64. 64×64 is both the on-screen footprint and the canonical per-frame size a convention-slot sheet is cut to — chosen to match the concept art already under `assets/` (`pigeon1.png`, `penguin1.png`, `tortoise.png`, all 64×64) and the `frame_w`/`frame_h` the sprite-generation tool that produced them already emits (see `metadata.json` inside e.g. `assets/pigeon1_walk.zip`). A sheet dropped at the conventional path is sliced into that many 64×64 frames straight off its own loaded pixel size — no frame count is assumed. `assets/pigeon*`, `assets/penguin*`, `assets/tortoise*` are in-progress art-pipeline output, not yet cut to this convention's per-state file naming, and carry no slot yet.

**Manny is the one alias**, not a convention-slot fit: his existing `assets/Manny-walk.png` (`walk`) and `assets/Manny-sweeping.png` (`working`) sheets — cut before this contract existed, at 256×256 per frame in a 5×5 grid — are fixed in `BuildingLayout.CHARACTER_SPRITE_FILE`, one-time the same way `ROOM_TYPE_INTERIOR_FILE` aliases the three painted Room interiors. They're scaled down to the same 64×64 footprint at render time. Manny has no `idle` sheet, so that one state falls through to the placeholder like any other character's would — proving the alias and the fallback share one resolver, not two code paths.

Both families' animation states are idle, walk, and one context state — sleeping for a Guest at Night, working for a Staffer at their Station — per ADR-0015/ADR-0020. There is no wander behaviour and no ambient behaviour scheduler.

### Tag icons, mood faces, Station props, HUD pills

Single static frame each, no animation states — the fallback and naming-convention shape is identical to the guest/Staffer sprites' convention branch (`<dir><id>.png`, else the tinted labelled placeholder), just without a `<state>` suffix or a sheet to slice.

| Slot | File | Size (px) | Ids |
| --- | --- | --- | --- |
| Tag icon (8) | `assets/tags/<tag_id>.png` | 24×24 | `data/tags.json`: `cold`, `warm`, `water`, `dry`, `high_perch`, `spacious`, `dark`, `quiet` |
| Mood face (3) | `assets/moods/<tier>.png` | 20×20 | `sim/patience_state.gd`'s `PatienceState.tier()` values: `calm`, `impatient`, `huffy` |
| Station post prop (3) | `assets/stations/<station_id>.png` | 40×40 | `sim/station.gd`'s `Station.IDS`: `reception`, `housekeeping`, `kitchen` |
| HUD pill (4) | `assets/hud/<pill_id>.png` | 96×28 | `cash`, `hearts`, `star`, `calendar` |

Mood faces are named after `PatienceState.tier()`'s actual return values (`calm`/`impatient`/`huffy`), not `CONTEXT.md`'s "content → impatient → huffy" prose gloss — this is the vocabulary the resolver is called with, since it's the vocabulary the existing Patience code already produces.

### `character_idle.png`/`.webp` and the two UUID-named PNGs

Unused leftovers with no code ever referencing them, predating this contract. Removed rather than left unreferenced — they get no slot.
