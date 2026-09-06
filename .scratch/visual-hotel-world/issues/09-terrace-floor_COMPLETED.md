# 08 — The Terrace as a place

**What to build:** Dining becomes somewhere in the hotel rather than a queue list. The Terrace band at Level 1 is the painted kitchen/bar pass as drawn — its redraw into a table-service bistro is later work, and this ticket takes the art it has.

Served and seated diners sit along the pass as characters, so a busy dinner service looks busy. Waiting diners queue at the Terrace entrance. Tapping the Terrace signage opens the existing Terrace menu with its Daily Special, Kitchen staffing and upgrade controls, preserving ADR-0010's tap-the-structure pattern.

The layout model gains diner placement: which seats along the pass are taken and where the entrance queue stands.

**Blocked by:** 06

**Status:** done

- [x] Seated and served diners appear as characters at the pass, one per Walk-in Diner or Dining Party being served
- [x] Waiting diners queue at the Terrace entrance
- [x] The number of visible diners tracks Terrace service state, with no list to read
- [x] Tapping the Terrace signage opens the existing Terrace menu unchanged
- [x] Diner placement is covered by tests against the pure layout model

## Comments

Implemented in `sim/building_layout.gd`: `terrace_diner_placements(walkin_queue, dinner_jobs)` buckets every `Sim.walkin_queue` entry -- a Walk-in Diner or a Dining Party alike, CONTEXT.md, both share that one queue -- into `"pass"` (a Kitchen Staffer is actively serving it, i.e. its `id` appears as an `entry_id` among `dinner_jobs`' values) or `"queue"` (still waiting), preserving `walkin_queue`'s own insertion order within each bucket rather than sorting, since (unlike a Staffer id) there's no natural sort key. `resolve_terrace_diner_point()` resolves a bucket+index placement to a world position -- the diner grid or the entrance queue line, both already reserved by ticket 05 but never rendered live until now. A new `signage` rect anchor plus `resolve_terrace_signage_rect()` gives the Terrace band a tap target over its floor sign, mirroring `STATION_POST_HIT_SIZE`'s "forgiving hit box" reasoning.

`autoload/sim_controller.gd` gained `dinner_jobs()`, a deep-duplicated read-only snapshot of the controller's private `_dinner_jobs`, so the UI layer never reaches into private Sim state (mirrors the existing `dinner_job(staffer_id)` single-lookup accessor).

`ui/hotel_world.gd` renders every diner via the new `ui/diner_actor.gd` (a `CharacterSprite` at the `guest` kind's `idle` state -- the first live use of that character kind, previously resolver-and-test-only per ticket 06) and wires a `terrace_tapped` signal straight to `main_screen.gd`'s existing `_on_terrace_tapped()` (unchanged, per ADR-0010). Diner actors rebuild whenever `Sim.walkin_queue` or its in-flight dinner Jobs change (a new `_dining_signature()` poll, same shape as the existing Stations/Rooms signature checks); the signage tap uses the same press/release-with-a-movement-threshold hit-testing as every other tap target in this file.

19 new tests: 10 in `tests/test_terrace_diner_placement.gd` (bucketing, point resolution, the signage rect's distinctness from the Terrace's other anchors), plus 1 in `tests/test_walkin_dinner.gd` for the new `dinner_jobs()` accessor -- same literal-dict, no-autoload shape as `tests/test_station_placement.gd`. Verified behaviorally via a throwaway GUT smoke test (not committed, same as ticket 07's own verification): instantiating `HotelWorld` directly, forcing an Evening walk-in queue, confirming one `DinerActor` per `walkin_queue` entry, and confirming a press+release on the signage rect emits `terrace_tapped`.

Full suite: 222 tests, 209 passing, 13 pre-existing failures -- confirmed via a stash/baseline comparison to be identical to the failures already present before this ticket's changes (unrelated: checkout/review, day-night-cycle, hotel-background-slices, integration-multiday, manual-seating, room-guest-dinner-addon).
