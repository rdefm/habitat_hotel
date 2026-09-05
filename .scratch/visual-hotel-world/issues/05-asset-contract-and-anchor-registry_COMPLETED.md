# 05 — The asset contract and the anchor registry

**What to build:** The document that says where everything in the building goes, and the code that resolves it — so art can be produced against a fixed target and dropped in without touching code.

The contract fixes, per slot: file path pattern, pixel dimensions, anchor point, frame count and animation states. This ticket covers the building side of it — the shell and elevator slices from ticket 03, per-Room-type floor and interior art, and the Reception and Terrace bands. It also states the fallback rule the whole contract obeys: a missing asset renders a placeholder occupying the identical footprint, tinted and labelled, and resolution lives in the layout model so the renderer never checks for a file. Ticket 06 applies that rule to characters.

Because the building is real art rather than a computed layout, the contract carries an **anchor registry**: the rects and points within each band where things stand — the two Room bays, the elevator door on each floor, the lobby queue line, the front desk, supply closet and staff nook positions, the Terrace's diner spots and its entrance queue. The layout model resolves an anchor plus a floor's position into a world position, and the renderer derives nothing of its own.

Three of the six Room types have painted interiors; the other three exercise the fallback and show a labelled placeholder band of identical footprint. That contrast is the ticket's own proof that the fallback works.

**Blocked by:** 04

**Status:** done

- [x] The contract document fixes path, dimensions, anchor, frame count and animation states for every building-side slot, and states the placeholder fallback rule for all slots
- [x] The anchor registry names every standing position in every band, and the layout model resolves each to a world position given the floor's placement
- [x] The three painted Room types render real interiors; the other three render labelled placeholders of identical footprint
- [x] A correctly-named, correctly-sized file dropped into a building slot replaces its placeholder with no code change
- [x] Anchor resolution and building-slot resolution with fallback are covered by tests against the pure layout model
- [x] The renderer contains no file-existence check

## Comments

Implemented in `sim/building_layout.gd` (extended, not a new file — the spec's "one pure module" decision from ticket 04 holds): `resolve_room_interior()` and the anchor registry (`resolve_anchor()` plus indexed `resolve_lobby_queue_point()`/`resolve_terrace_entrance_queue_point()`/`resolve_terrace_diner_spot()`). 22 tests in `tests/test_anchor_registry.gd`. `ui/hotel_world.gd` draws whichever interior/placeholder the model picks; `docs/asset_contract.md` documents both the anchor registry and the interior assignment.

Room type → interior assignment, chosen by theme against `data/rooms.json` tags: `lagoon_room` (warm/water) → the jungle band, `ice_grotto` (cold/water) → the ice band, `roost_loft` (high_perch/dry) → the bamboo band. `cozy_nook`, `cavern_suite`, `tundra_hall` render the fallback — a tinted, labelled placeholder, each with its own distinct tint.

The "drop a file in, no code change" checkbox needed more than a static id→file map: the three painted types' files are named thematically (ticket 03 cut them before any Room type was assigned), so they're a one-time alias table, but every *other* Room type — including the three fallback ones — resolves through an open naming convention (`room_interior_<room_type_id>.png` under `assets/hotel_shell/`), checked directly against the file on disk (real height read off the loaded texture, not assumed). So `cozy_nook`/`cavern_suite`/`tundra_hall` already have an open slot waiting; landing a correctly-sized file at that path needs no code change, same as the three aliased types. `resolve_room_interior()` takes an injectable `probe_fn` so this is tested without touching the real filesystem.

Two Room types (`ice_grotto`, `roost_loft`) have a painted band shorter than the generic tiled `ROOM_FLOOR_HEIGHT` (131px/158px vs. 174px) — `floors()` now takes a Room floor's height from its resolved interior rather than assuming the generic constant, and the anchor registry's `bay_left`/`bay_right`/`elevator_door` resolve relative to each floor's own height, so a shorter painted floor gets correspondingly shorter bays rather than clipped or gapped ones.

**Unplanned but necessary: the vendored GUT test framework didn't run on this machine's Godot at all.** `addons/gut/error_tracker.gd`'s `extends Logger` and typed `Array[ScriptBacktrace]` fail to parse on Godot 4.4 (confirmed directly with a minimal repro, not inferred) — GUT 9.6.1 targets a later engine line than this project's pinned 4.4 (`project.godot`'s `config/features`). Rather than upgrade the machine's Godot (the user has another 4.4 project and didn't want the system install touched), patched three vendored GUT files to degrade gracefully: `error_tracker.gd` (Logger hook → no-op, loses auto-fail-on-stray-engine-error), `godot_singletons.gd` (drops two Navigation singleton classes 4.4 doesn't have), `orphan_counter.gd` (`Node.get_orphan_node_ids()` → empty list, loses per-test orphan-node detail; the orphan *count* still works via `Performance.get_monitor()`). No assert-based test outcome is affected. Full suite: 158 tests, 145 passing, 13 failing — confirmed via an A/B run that all 13 failures are pre-existing and unrelated to this ticket (identical failure set with this ticket's changes removed).

Also noticed mid-session: several untracked art files appeared under `assets/` (`pigeon*`, `penguin*` — zips and one PNG, no `.import` files yet) that look like a concurrent, in-progress asset drop unrelated to this ticket. Left out of this ticket's commit; flagged to the user rather than committed or deleted.
