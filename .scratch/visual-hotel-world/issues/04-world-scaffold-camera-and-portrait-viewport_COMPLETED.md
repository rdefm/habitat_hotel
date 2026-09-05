# 04 — World scaffold: the composed building, the camera, and the portrait viewport

**What to build:** The hotel drawn as an actual building, framed on screen, in a phone-shaped window — with the old Control view still one toggle away.

The game runs in a portrait viewport of roughly 720×1280 with `canvas_items` stretch and `expand` aspect, so a desktop window letterboxes rather than reflows. A `Node2D` world mounts where the old `ScrollContainer` sat, selected by a development toggle so both views stay runnable; the HUD strip and the modal hosts stay Controls above it.

The building composes itself from ticket 03's slices, bottom to top: ground plinth, the lobby band as the Ground Floor, the Terrace band at Level 1, then one interior band per unlocked Room type in ascending unlock-Star order (ties broken by array order in `data/rooms.json`), the frame column and elevator shaft tiling alongside, and the roofline capping the top. A newly unlocked Room type adds its band on top and never renumbers the floors below it. Each floor carries a painted sign reading its level number and Room type name; Reception is the Ground Floor and is not numbered. The sky sits behind it all as its own layer and tints across Morning, Midday, Evening and Night — Night is about five seconds of real time at 1x, so the easing is tuned for a short window.

A `Camera2D` frames the whole building by default. Scroll or pinch zooms within clamped bounds, drag pans, and a control eases back to fit-all. Fit-all bounds are recomputed when a floor is added.

This ticket starts the one new seam: a pure `RefCounted` module of static functions, no node or autoload dependencies, mirroring the shape of `sim/match_hint.gd`, which derives the building's description from `GameState`/`Sim` state. Here it answers floor ordering, level numbering, the band composition per floor, and the fit-all bounds — and it is the only new test target. It also starts the asset contract document, covering the shell slots this ticket consumes.

A new ADR records the Node2D-world decision and supersedes ADR-0016.

**Blocked by:** 03

**Status:** done

- [x] The game runs in a portrait window; a desktop window letterboxes instead of reflowing
- [x] A development toggle selects the old Control view or the new world, and both are playable
- [x] The building draws bottom-to-top as Ground Floor Reception, Terrace at Level 1, then Room floors in ascending unlock Star, verified against a case where an alphabetical sort would differ
- [x] Unlocking a new Room type adds its floor on top and leaves every existing floor's level number unchanged
- [x] Each floor shows a sign with its level number and Room type name; the Ground Floor is unnumbered
- [x] The camera frames the whole building on load and reframes when a floor is added
- [x] Scroll/pinch zooms within clamped bounds, drag pans, and a control eases back to fit-all
- [x] The sky tints across all four day phases and reads correctly during the short Night window
- [x] Floor ordering, level-number stability across an unlock, band composition and fit-all bounds are covered by tests against the pure layout model, built from literal state with no autoloads
- [x] A new ADR records the decision and marks ADR-0016 superseded

## Comments

Implemented as `sim/building_layout.gd` (the pure layout model, 16 tests in `tests/test_building_layout.gd`) and `ui/hotel_world.gd` (the `Node2D` renderer), wired into `ui/main_screen.gd` behind `USE_HOTEL_WORLD`. `docs/adr/0020-node2d-world-and-camera.md` records the decision; `docs/asset_contract.md` starts the asset contract with the shell slots this ticket consumes (ticket 05 adds the anchor registry and per-Room-type interior assignment).

Room floors without a painted interior of their own (all six Room types, until ticket 05 assigns three) render as the reusable frame-column/elevator-shaft tiles from ticket 03 flanking a plain tinted placeholder, per the spec's staged migration.

Two non-obvious things worth flagging for later tickets:

- **Camera2D.zoom convention.** This project's `canvas_items` + `expand` stretch setup makes `Camera2D.zoom` a magnification factor (larger zoom = more zoomed in), confirmed empirically with a probe sprite rather than trusting stretch-agnostic docs from memory — the fit-all math and clamp direction in `ui/hotel_world.gd` depend on this.
- **`Camera2D.current = true` fails under `--headless`** ("Invalid assignment of property... on a base object of type 'Camera2D'"), reproduced in isolation, unrelated to this scene. Used `make_current()` instead, which works under both headless and windowed runs.

Also fixed a pre-existing, unrelated format-string bug in `ui/hotel_panel.gd` (separate commit) found while verifying the old view still runs with the toggle flipped off.
