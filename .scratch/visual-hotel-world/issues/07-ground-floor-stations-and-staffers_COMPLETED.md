# 06 — Ground floor: Station posts, the staff nook, and Staffer assignment

**What to build:** Staffing becomes placing someone somewhere. Each of the three Stations is a physical post: Housekeeping a supply closet at the lobby's existing door, Reception a front desk, Kitchen the Terrace pass upstairs (ADR-0010 unchanged). The desk, closet and nook are placeholder props at their contract anchors over the current lobby art — real lobby art drops into the same slots later with no code change.

An assigned Staffer stands at their post; a Staffer with no Station loiters in a staff nook beside the desk, so who is free is answered by looking. Dragging a Staffer onto a post assigns them through the existing `GameState.reassign_staffer()`/`Sim.assign_staffer()` path, and tapping one still opens their Skill/Trait detail. The hit target for a post is decided per target — a thin invisible Control in front of the art, or an `Area2D` with hand-rolled drag, whichever is cheaper — the constraint is that the gesture works, not which node type serves it.

The layout model gains actor placement bucketing: which post, nook or band each Staffer belongs to.

**Blocked by:** 01, 06

**Status:** done

- [x] Three Station posts are drawn at their anchors: supply closet, front desk, Terrace pass
- [x] An assigned Staffer stands at their post, and reassigning moves them there
- [x] Unassigned Staffers stand in the staff nook
- [x] Dragging a Staffer onto a post assigns them via the existing GameState/Sim path, with no new Sim state
- [x] Tapping a Staffer opens their existing Skill/Trait detail
- [x] A Station's staffing level is readable from the sprites standing at it, with no card to count
- [x] Staffer placement bucketing is covered by tests against the pure layout model

## Comments

Implemented in `sim/building_layout.gd`: `resolve_station_post_anchor()` maps each of `sim/station.gd`'s three `Station.IDS` to a floor index (Reception/Terrace are always `floors()`'s fixed first two entries, so this is a hardcoded 0/1) and an anchor name -- `front_desk`/`supply_closet` on the Reception band, and a new `kitchen_pass` anchor added to the Terrace band for ADR-0010's "Kitchen is the Terrace pass". `staffer_bucket()`/`staffer_placements()`/`resolve_staffer_point()` are the placement-bucketing model: every Staffer lands in a `"post:<station_id>"` bucket if `GameState.stations` has them assigned, or `"nook"` by elimination against the full roster if not; same-bucket Staffers stack side by side off `STAFFER_STACK_OFFSET`, sorted alphabetically for a stable render order. 11 new tests in `tests/test_station_placement.gd`, same shape as `tests/test_anchor_registry.gd` -- literal ids/dicts in, no autoloads, no nodes.

`ui/hotel_world.gd` renders the three posts (a `CharacterSprite` per `resolve_station_prop()`, first rendered live here -- ticket 06 left it resolver-and-test-only) and every Staffer (`ui/staffer_actor.gd`, new, wrapping a `CharacterSprite` at rest state `"idle"`) at their placement, rebuilt whenever a floor unlocks or `GameState.stations` changes (a `str()`-signature poll alongside the existing floor-count poll, since Reception/Terrace never move so only the Staffer actors need refreshing on a reassignment). `ui/character_sprite.gd` gained a static (non-sliced) sprite branch so it can render a single-frame resolver's "sprite" dict (no `frame_width`/`frame_height`, since there's only one frame) as well as the animated-sheet dicts it already handled.

Drag-and-drop is hand-rolled against world-space rects rather than Godot's Control-only `_get_drag_data()` API, per spec.md's "whichever is cheaper": `HotelWorld` tracks a press/release against each `StafferActor.hit_rect()` and `Station` post's drop-target rect, with a small movement threshold splitting a tap (emits `staffer_tapped`, wired to the existing `StafferDetailMenu` popup in `ui/main_screen.gd`) from a real drag (calls the existing `Sim.assign_staffer()` if released on a post, a no-op otherwise). No new Sim state, per the ticket's own constraint.

Manny now renders his placeholder at rest like any other Staffer's idle state would, rather than ticket 06's hardcoded walk-cycle demo -- nothing yet drives a `"working"` state (that's tickets 08/13's Job travel), and he has no `idle` sheet, so this isn't a regression of ADR-0015's closed constraint (which is about the resolver accepting a new sprite set per Staffer/task with no redesign, not about Manny always animating).

Verified behaviorally via a throwaway GUT smoke test (instantiating `HotelWorld` directly, not committed) rather than pixel screenshots -- this sandbox's headless dummy rendering driver can't produce a real viewport texture (`get_viewport().get_texture().get_image()` returns null), unlike whatever setup ticket 06's screenshot verification ran under. Confirmed: the world builds 3 posts + 3 Staffer actors with Biscuit/Shelly/Manny at their correct default positions; a press+release with no movement on a Staffer emits `staffer_tapped`; dragging Manny onto the Kitchen post calls through to `Sim.assign_staffer()` and the next render pass moves him there; a sub-threshold jiggle still counts as a tap; and a drag released off every post is a no-op.

Full suite: 193 tests, 181 passing, 12 pre-existing failures -- same set prior tickets' runs already confirmed unrelated.
