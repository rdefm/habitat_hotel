# 13 — Terrace upgrades

**What to build:** The Terrace gets an upgrades list the same shape as a Room's — purchasable/earnable with cash/Hearts, applying effects the same way Room upgrades do — surfaced through the same Upgrade-menu pattern already used for Rooms (ADR-0003).

**Blocked by:** 09

**Status:** done

- [x] The Terrace has its own list of available upgrades, purchasable with cash/Hearts like a Room's
- [x] A purchased Terrace upgrade's effects are reflected in Dining outcomes (e.g. score/capacity/quality) the same way a Room upgrade affects a stay
- [x] Already-purchased Terrace upgrades persist and are queryable the same way a Room's are

## Comments

New `data/terrace.json`: `{upkeep_per_day, upgrades: [...]}` -- upgrades are the same per-instance-modifier shape as a Room type's `upgrades` array (`id`/`name`/`description`/`cost_cash`/`cost_hearts` required, at least one effect field), minus `adds_tag` (the Terrace has no tags to add). Three effect fields, deliberately mirroring `ROOM_UPGRADE_EFFECT_FIELDS` minus `adds_tag`: `satisfaction_bonus`, `capacity_delta`, `upkeep_delta`. Seed catalog: `seasoned_recipes` (satisfaction_bonus +10), `extra_seating` (capacity_delta +1), `outdoor_awning` (upkeep_delta -4). `DataLoader.load_terrace()`/`_validate_terrace_upgrade()` follow `load_rooms()`/`_validate_room_upgrade()`'s validation shape.

`GameState.terrace` (loaded, read-only content) + `GameState.terrace_upgrades` (mutable purchased-id `Array`, reset alongside the rest of session state in `reset_to_starting_conditions()` -- same persistence contract as a Room instance's `upgrades` array, just living directly on `GameState` since the Terrace is a single fixed structure, not per-instance). New query/purchase trio mirroring the Room upgrade section exactly: `effective_terrace_stats()` (merges purchased upgrades' effects onto the base `upkeep_per_day`), `available_terrace_upgrades()`, `purchase_terrace_upgrade(upgrade_id)`.

Three Dining outcomes now read `effective_terrace_stats()`, each the same way a Room upgrade already feeds a stay: `Satisfaction.compute_dining()` gained an optional `terrace_satisfaction_bonus` param (default 0, so every existing caller/test is unaffected) added straight into the score, mirroring `compute()`'s `room_type.get("satisfaction_bonus", 0)` term -- wired in at `Sim._serve_walkin_diner()`. `Sim._populate_walkin_queue()`'s Walk-in count range (`dining.walkin_count_min/max`) now shifts by `capacity_delta` at both ends before the `Rng.randi_range()` draw -- a capacity upgrade widens the range a busier Evening can land in, not a guaranteed extra Diner. `Sim._do_night()`'s nightly upkeep sum now adds `effective_terrace_stats()["upkeep_per_day"]` alongside every Room's, same accounting path.

New tests: `tests/test_terrace_upgrades.gd` (extends `sim_test_base.gd`, following `test_build_room.gd`'s GameState-query style plus `test_dining_reputation.gd`'s Sim-integration style) -- catalog listing, purchase success/failure (unknown id, already-purchased, insufficient cash, insufficient Hearts), persistence across `reset_to_starting_conditions()`, `effective_terrace_stats()` merging all three effect fields, and one integration test per wired effect (satisfaction_bonus raising a served Walk-in Diner's score, capacity_delta widening the Evening's queue-size range, upkeep_delta reducing the nightly bill).

No UI in this ticket -- ticket 14 ("Terrace's own Upgrade menu (reusing the pattern from tickets 03/13)") owns surfacing `available_terrace_upgrades()`/`purchase_terrace_upgrade()` in a menu, matching how ticket 13's own text frames it as data/effects work with ticket 14 doing the reuse.

Verification note: this environment's vendored `Godot_v4.4-stable_win64_console.exe` still can't run the GUT suite (same pre-existing 4.4-vs-4.7 gap prior tickets documented). Verified via a headless `--batch=5` smoke run (no errors, `data/terrace.json` parses cleanly) plus a one-off headless `--script` smoke run exercising every new `GameState`/`Sim` code path in this ticket (catalog, purchase success/failure/persistence, `effective_terrace_stats()` merge, and all three wired Dining-outcome effects) -- deleted after verification, not committed.
