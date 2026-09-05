# Asset contract

Where everything in the drawn hotel world (`ui/hotel_world.gd` and its successors) goes, so art can be produced against a fixed target and dropped in without touching code. Started by ticket 04 (ADR-0020), covering only the building-shell slots that ticket's renderer consumes; ticket 05 extends this document with the full anchor registry (standing positions within each band), the per-Room-type interior assignment and its placeholder fallback, and the Reception/Terrace bands' own anchors. Ticket 06 does the same for character slots.

**Fallback rule (states now, applies everywhere in this contract):** a missing asset renders a placeholder occupying the identical footprint, tinted and labelled. Resolution lives in the layout model (`sim/building_layout.gd` today; the anchor registry ticket 05 adds extends it) — the renderer never checks whether a file exists on disk.

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
| Room interior (jungle/ice/bamboo) | `room_interior_jungle.png` / `room_interior_ice.png` / `room_interior_bamboo.png` | 572×174 / 572×131 / 572×158 | top-left corner at that floor's top edge | Sliced by ticket 03; **not yet wired to a specific Room type id or rendered by ticket 04** — every Room floor today renders the tiled placeholder below regardless of type. Ticket 05 assigns three of the six Room types to these bands and renders the other three as the placeholder, proving the fallback. |

### Tiled Room floor composition (no painted interior assigned yet)

Every Room floor renders this way until ticket 05 assigns real interior art. Left to right, within the floor's 572px width:

| Region | x range | Content |
| --- | --- | --- |
| Left frame column | 0–71 | `frame_column_left.png` |
| Elevator shaft | 71–168 | `elevator_shaft_segment.png` |
| Interior placeholder | 168–501 | Plain tinted `ColorRect` (ticket 04's stand-in; ticket 05 replaces this with real/placeholder interior art per the anchor registry) |
| Right frame column | 501–572 | `frame_column_right.png` |

Height is fixed at 174px per generic Room floor (`sim/building_layout.gd`'s `ROOM_FLOOR_HEIGHT`) — the same span the frame column and shaft tiles were cut from, so one copy per floor is already the correct height with no repetition needed within a single floor.

### Floor signs

Every floor (Reception, Terrace, each Room floor) carries a sign reading its level number and name — `Level %d — %s` for Terrace/Room floors, `Reception` alone for the unnumbered Ground Floor. Ticket 04 renders this as a plain `Label` in the top-left corner of the floor's band; no painted sign asset exists yet.
