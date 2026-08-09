# 10 — Walk-in dinner queue + Daily Special

**What to build:** Walk-in Diners arrive at the Terrace during the Evening on their own Patience timer, independent of the Room-booking Party queue. The player chooses one Daily Special each day that biases which Species show up as Walk-in Diners that evening. Serving dinner/walk-in demand requires a higher Kitchen skill threshold than breakfast — a Staffer who clears breakfast fine may still be unable to keep up with dinner.

**Blocked by:** 09

**Status:** done

- [x] Walk-in Diners arrive only during the Evening phase, on a queue and Patience timer independent of the Room-booking arrivals queue
- [x] Choosing a Daily Special measurably biases which Species appear as that evening's Walk-in Diners
- [x] A Kitchen Staffer above the dinner skill threshold can serve both breakfast and dinner/walk-in demand
- [x] A Kitchen Staffer above the breakfast threshold but below the dinner threshold can serve breakfast but not dinner/walk-in demand
- [x] A Walk-in Diner whose Patience expires unserved walks away

## Comments

`Sim.walkin_queue` (new public/queryable `Array`, parallel to `pending_arrivals`/`breakfast_queue`): `{id, name, species_id, party_size, patience}`. `Sim._populate_walkin_queue()` rebuilds it from scratch the moment Evening starts (`_do_evening()`), drawing a fresh count from `data/balance.json`'s `dining.walkin_count_min/max` -- unlike `breakfast_queue`'s guest-per-occupied-Room source, this is new demand, not tied to current Room occupancy, and (per ADR-0003) never Star-gated. `Sim._do_night()` force-clears `walkin_queue`/`_dinner_jobs` when Evening ends, same "no bailout" framing as `pending_arrivals`' Evening-boundary expiry.

`DemandGenerator.pick_walkin_species()` picks each Walk-in Diner's Species: `dining.walkin_special_bias_chance` (0.5) chance of pulling exactly `GameState.daily_special` if one's set, otherwise a uniform pick across every Species. `GameState.set_daily_special(species_id)` validates against `species` and is the only mutator (rejects an unknown id, `""` clears it) -- picking one is ticket 14's UI concern, this ticket just built where the choice lives and how it's applied.

Dinner reuses breakfast's parallel-per-Staffer-job shape (`_tick_dinner()` mirrors `_tick_breakfast()`/`_breakfast_jobs`) but gated on a higher `stations.kitchen.dinner_min_skill` (3, vs `breakfast_min_skill` 2): Biscuit (kitchen skill 1) clears neither, Shelly (2) clears breakfast only, Marlon (3) clears both. A new `_kitchen_busy()` check (either `_breakfast_jobs` or `_dinner_jobs` has the Staffer) keeps a dual-qualified Staffer from claiming both at once -- breakfast's claim pass runs first each tick, so a Staffer with a pending breakfast entry finishes that before ever picking up a Walk-in Diner. Reassigning a Kitchen Staffer mid-dinner-job drops only their own job (`_dinner_jobs.erase()` in `assign_staffer()`); the Walk-in Diner's queue entry goes back to waiting, same as ticket 09's breakfast interruption behavior.

`Sim._decay_walkin_patience()` mirrors `_decay_patience()`'s shape: decays only while Evening is active, freezes for an entry currently mid-job, and burns Patience at `dining.walkin_patience.unstaffed_multiplier` (1.6x) when Kitchen has no Staffer assigned at all -- matching CONTEXT.md's Patience entry ("faster if the relevant Station is unstaffed"). An expired entry (`patience <= 0`) is removed from `walkin_queue` immediately, same as a Room-booking Party's walk-away.

New tests: `tests/test_walkin_dinner.gd` (extends `sim_test_base.gd`) -- 10 tests covering all five checkboxes plus the interrupted-mid-job case and both the staffed/unstaffed Patience decay rates.

Verification note: as in tickets 09/11, this environment's vendored `Godot_v4.4-stable_win64_console.exe` (4.4) can't run the GUT suite against this project (`config/features` requires 4.7). Verified instead via a one-off headless `--script` smoke run (autoloads fetched via `root.get_node()`, one `process_frame` await to let data load) exercising all five criteria directly through `Sim`/`GameState`/`Clock`: confirmed `walkin_queue` empty before tick 161 and populated the instant Evening starts; Marlon (skill 3) draining `walkin_queue` entries while Shelly (skill 2) staffed alone left the queue untouched across 6 individually-inspected ticks (`Sim.dinner_job("shelly")` stayed `{}` the whole time); and an unstaffed, low-Patience entry hit 0 and was removed within the expected tick count. Script deleted after verification, not committed.
