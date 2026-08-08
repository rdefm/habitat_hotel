# 09 — Terrace breakfast service loop

**What to build:** The Terrace exists as a fixed structure from Day 1, present and operating without ever being built or star-gated, exactly like Reception (ADR-0003). Each Morning, every currently-occupied Room's guest joins a breakfast queue, served by whichever Staffer is on Kitchen duty, gated by a minimum Kitchen skill threshold below which a Staffer can't serve breakfast at all.

**Blocked by:** 07

**Status:** done

- [x] The Terrace is present and functioning on Day 1 with no build or unlock action required
- [x] Every currently-staying guest joins the breakfast queue each Morning phase
- [x] A Kitchen Staffer at or above the breakfast skill threshold serves queued breakfast guests
- [x] A Kitchen Staffer below the breakfast skill threshold cannot serve breakfast
- [x] An empty Kitchen Station means no breakfast guest is served that day

## Comments

The Terrace itself needed no new gating code -- it was already "present from Day 1" by construction (nothing in `GameState`/`Sim` ever checked a build/unlock flag before this ticket, unlike a Room's `can_build_room_type()`). What ticket 09 actually builds is the breakfast queue + Kitchen-gated serving loop, following ticket 07's Housekeeping pattern almost exactly.

`Sim.breakfast_queue` (new public/queryable `Array`, same shape-of-contract as `pending_arrivals`): `{id, guest_id, room_type_id, instance_id, species_id, party_size}`, one entry per currently-occupied Room. `Sim._populate_breakfast_queue()` rebuilds it from scratch every Morning (called from `_do_morning()` right after checkouts resolve, before that day's arrivals are drawn) -- an unserved entry does *not* carry into tomorrow, matching the reference prototype's `populateBreakfastQueue()`.

`Sim._tick_breakfast()` (called every tick from `_on_tick_advanced()`, unconditional on phase like `_tick_housekeeping()`/`_tick_checkins()`) mirrors `_tick_housekeeping()`'s parallel-per-Staffer-job shape: every Kitchen Staffer not already mid-job claims the next unclaimed queue entry and works it down over a Skill-dependent tick count, tracked in a new `Sim._breakfast_jobs` dict (`staffer_id -> {entry_id, ticks_remaining}`). The one real deviation from Housekeeping's pattern: a Staffer whose `skills.kitchen` is below `data/balance.json`'s new `stations.kitchen.breakfast_min_skill` never claims a job at all, regardless of how idle they are -- that's the actual gate this ticket asked for. An empty Kitchen Station falls out for free: no assigned Staffers means the claim loop never runs, so the queue just never drains, same "no bailout deadline" behavior as Housekeeping leaving Rooms dirty indefinitely.

`data/balance.json`'s `stations.kitchen`: `breakfast_min_skill: 2` (deliberately *not* the reference prototype's `BREAKFAST_MIN_SKILL = 1`, which was effectively "is anyone assigned at all" and could never fail the "below threshold" checkbox -- skill 1 is a Staffer's floor, so a threshold of 1 is unfalsifiable). `2` splits `data/staffers.json`'s roster cleanly: Biscuit (kitchen skill 1) sits below, Shelly (2) and Marlon (3) sit at/above. `breakfast_ticks_by_skill`/`default_breakfast_ticks` are the reference's `BREAKFAST_SECONDS_BY_SKILL` (`{1:6, 2:5, 3:4, 4:3.5, 5:3}` seconds) converted to ticks at `Clock.TICK_DURATION` (0.25s/tick) the same way ticket 07 converted Housekeeping's constants.

`Sim.assign_staffer()` now also erases `_breakfast_jobs[staffer_id]` (alongside the existing `_cleaning_jobs.erase()`) when a Staffer actually moves Stations -- reassigning a Kitchen Staffer mid-serve drops only their own job; the queue entry itself isn't touched, so the guest just goes back to waiting for the next available Staffer, matching ADR-0005's "interrupted dinner/breakfast job just goes back to waiting."

Added query methods `Sim.breakfast_entry(entry_id)`/`Sim.breakfast_job(staffer_id)`, parallel to the existing `pending_party()`/`cleaning_job()`, for tests and ticket 14's future UI.

Explicitly out of scope per the ticket (deferred to later tickets in this batch): no revenue/Hearts/Reputation effect for a served or unserved breakfast guest (ticket 11), no Patience/walk-away behavior on the breakfast queue (not in this ticket's acceptance criteria -- contrast with ticket 10's Walk-in Diners, which do get their own Patience timer), no EventBus signal for a served breakfast entry (nothing consumes one yet; can be added alongside ticket 14's UI work if needed).

New tests: `tests/test_terrace_breakfast.gd` (extends `sim_test_base.gd`, following `test_roster_station.gd`'s conventions) cover all five checkboxes plus a sixth case (reassigning a Kitchen Staffer mid-job interrupts only their own job, mirroring ticket 07's equivalent Housekeeping test).

Verification note: this environment's vendored `Godot_v4.4-stable_win64_console.exe` still can't run the GUT suite (same pre-existing 4.4-vs-4.7 gap prior tickets documented -- confirmed again this session). Verified instead via a headless `--batch=10` smoke run (no errors across 10 simulated days with an unstaffed Kitchen exercising the "never drains" path) plus a one-off headless `--script` smoke run that staffed Kitchen with Shelly (skill 2, at threshold), seated a guest, and confirmed `breakfast_queue` populated at Day 1 Morning and fully drained after `breakfast_ticks_by_skill["2"]` (20) ticks -- both scripts deleted after verification, not committed.
