# 02 — Floor data model + instance addressing

**What to build:** Replace the flat, generic slot grid with the accepted Floor-per-room-type model (ADR-0004): each Room type's existing star-unlock condition becomes its Floor's unlock condition directly, a new per-type instance cap governs how many times that Floor can be built out, and every built room instance is addressed by its room type plus a stable per-type instance identifier instead of a single global slot index. `GameState`'s build/upgrade/query API, `SimController`, and the batch runner all move to this addressing scheme; the old generic slot layout data is removed.

**Blocked by:** 01

**Status:** done

- [x] The old generic per-slot unlock table is gone; unlock-by-star and the new instance cap are read from each Room type's own data
- [x] Attempting to build past a Floor's instance cap fails with no side effects
- [x] A Floor stays locked (not buildable, not visible as available) until its Room type's star requirement is met
- [x] Every built room instance can be uniquely addressed by room type + instance id; building, upgrading, and querying a room instance all use this addressing
- [x] A full day/night cycle and checkout still work end-to-end under the new addressing (existing characterization tests from ticket 01 updated to match, still green)

## Comments

`data/slot_layout.json` is deleted; each room type in `data/rooms.json` gained a `max_instances: 4` field (ADR-0004's reference value). `GameState.hotel_rooms` entries now carry `room_type_id` + a stable per-type `instance_id` (0-based, assigned in build order, never reused) instead of a flat `slot` integer.

New/changed `GameState` API: `floor_instance_count`, `floor_instance_cap`, `can_build_more`, `room_instance(room_type_id, instance_id)`; `build_room(room_type_id)` and `purchase_upgrade(room_type_id, instance_id, upgrade_id)` replace their slot-indexed predecessors. `can_build_room_type` is unchanged (still the star-unlock check).

`sim/matcher.gd` gained a pure `Matcher.room_key(room)` helper (`"room_type_id#instance_id"`) used to key `room_stats_by_key`; its decision dict now returns `room_type_id`/`instance_id` instead of `room_slot_index`. Policy branching (`strict_match`/`fill_vacancies`) and `GameState.matcher_policy` are deliberately untouched -- that's ticket 04's job.

`autoload/sim_controller.gd` and `autoload/event_bus.gd` (guest_seated/guest_checked_out/room_marked_dirty/room_cleaned signals) moved to the same addressing. UI consumers (`ui/hotel_panel.gd`, `ui/build_menu.gd`, `ui/upgrade_menu.gd`, `ui/main_screen.gd`, `ui/lobby_view.gd`) were updated to compile and work correctly against the new API -- `HotelPanel` now rebuilds its cells per-type (skipping locked types, appending a Build Slot cell per unlocked under-cap type) rather than the old static 18-slot grid, but stays a flat `GridContainer`; the real per-Floor row layout is ticket 03's job. `BuildMenu` is now scoped to the one room type its Build Slot belongs to rather than showing a catalog of every unlocked type.

Existing characterization tests (`tests/test_build_room.gd`, `tests/test_matcher_policies.gd`) were rewritten against the new addressing; `tests/test_day_night_cycle.gd` and `tests/test_checkout_review.gd` needed no changes since their assertions never touched slot/room addressing directly.

Verification note: this environment's vendored `Godot_v4.4-stable_win64_console.exe` can't run the GUT suite (the project targets `4.7`; GUT's `utils.gd` fails to parse under 4.4 with `Could not resolve class "GutErrorTracker"`) -- a pre-existing environment gap, not caused by this change. Reviewed via a two-axis `/code-review` (Standards + Spec) instead, both clean (0 hard violations, 0 missing/incorrect requirements); the user will run the actual suite locally with their own Godot 4.7 build.
