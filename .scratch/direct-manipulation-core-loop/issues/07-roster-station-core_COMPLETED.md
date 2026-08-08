# 07 — Roster & Station core

**What to build:** A fixed Roster of three authored Staffers (Biscuit, Marlon, Shelly), each carrying a 1-5 skill rating at every Station (Reception, Bellhop, Housekeeping, Kitchen) per ADR-0002/0005. Stations hold a list of assigned Staffer ids rather than a single slot, and a Staffer can be (re)assigned to any Station at any time. Reassigning a Staffer who's mid-task interrupts only that Staffer's own in-flight job — a half-cleaned Room reverts to dirty — without affecting any other Staffer's progress. Leaving a Station empty visibly degrades that Station's service: no Reception Staffer burns Patience faster, no Bellhop slows down check-in, no Housekeeping leaves rooms dirty longer than when a Staffer is covering it.

**Blocked by:** 04

**Status:** done

- [x] The three authored Staffers exist with a skill rating at each of the four Stations
- [x] A Staffer can be assigned or reassigned to any Station at any time via the sim's public API
- [x] Reassigning a Staffer mid-task reverts only that Staffer's own in-flight job (e.g. a half-cleaned Room goes back to dirty) and leaves every other Staffer's in-flight job untouched
- [x] An empty Reception Station measurably increases Patience decay versus a staffed one
- [x] An empty Bellhop Station measurably slows check-in versus a staffed one
- [x] An empty Housekeeping Station leaves rooms dirty for measurably longer than a staffed one
- [x] Kitchen Station assignment/skill is tracked here even though its gating effect isn't wired to Dining until ticket 09

## Comments

New module `sim/station.gd` (`Station`, a pure `RefCounted` const-holder like `MatchHint`/`PatienceState`): `Station.IDS := ["reception", "bellhop", "housekeeping", "kitchen"]` is the single source of truth for valid Station ids, used by `DataLoader`'s new staffer validation, `GameState`'s Station-assignment queries/mutation, and `Sim`'s reassignment path.

New data file `data/staffers.json`: the three authored Staffers (`biscuit`/`marlon`/`shelly`, matching `habitat-hotel-prototype-4.html`'s `STAFF` array) each with `skills: {reception, bellhop, housekeeping, kitchen}` (1-5, lopsided toward a home specialty). `DataLoader.load_staffers()`/`_validate_staffer()` follow the existing loader pattern (push_error + skip on malformed entries). `GameState.staffers` holds the loaded Roster; `GameState.stations` (Station.IDS' id -> Array of assigned Staffer ids) is the mutable assignment, reset to `DEFAULT_STATION_ASSIGNMENTS` (Biscuit/Reception, Marlon/Bellhop, Shelly/Housekeeping, Kitchen empty — the reference prototype's starting coverage) in `reset_to_starting_conditions()`.

`GameState` gained the Roster/Station query API (`station_staffers`, `is_station_staffed`, `staffer_station`) and a pure data mutation `reassign_staffer(staffer_id, station_id)` (moves a Staffer between Station lists, no-ops if already there, false for an unknown id). `Sim.assign_staffer(staffer_id, station_id)` is the public reassignment path everything (interactive UI in ticket 08, tests) calls: it drops the Staffer's in-flight Housekeeping job (if any, and only if they're actually moving to a different Station) before delegating to `GameState.reassign_staffer()`.

Effect wiring, translated from the reference prototype's second-based constants at `Clock.TICK_DURATION` (0.25s/tick) into a new `data/balance.json` `stations` section:
- **Reception**: `_decay_patience()` multiplies the per-tick Patience decay by `stations.reception.unstaffed_patience_multiplier` (1.6, matching the prototype's `RECEPTION_UNSTAFFED_PATIENCE_MULTIPLIER`) whenever `GameState.is_station_staffed("reception")` is false. Presence-only, not Skill-scaled.
- **Bellhop**: `_start_checkin()`, called from `_admit_guest()`, evaluates Bellhop coverage once at seat time (mirrors the prototype's `seatGuest()`) — staffed seats the guest straight in; unstaffed sets the Room's new `checking_in`/`checkin_ticks_remaining` fields to a flat `stations.bellhop.unstaffed_checkin_delay_ticks` (16 ticks = 4s, matching `CHECKIN_DELAY_SECONDS`) delay, ticked down every tick by the new `_tick_checkins()`. Presence-only here too.
- **Housekeeping**: `_tick_housekeeping()` replaces the old bulk "clean every dirty Room at Evening" sweep in `_do_evening()` with parallel per-Staffer cleaning jobs (`Sim._cleaning_jobs`, keyed by staffer_id): every assigned Housekeeping Staffer not already mid-job claims the next dirty, unclaimed Room and works it down over a Skill-dependent tick count (`stations.housekeeping.clean_ticks_by_skill`, `{1:40, 2:32, 3:26, 4:20, 5:16}` ticks = the prototype's `CLEAN_SECONDS_BY_SKILL` seconds x 4). An unstaffed Housekeeping Station simply never drains the queue — dirty Rooms stay dirty indefinitely, matching the prototype rather than inventing a bailout deadline. `Sim.assign_staffer()` interrupting a Staffer's job just erases their `_cleaning_jobs` entry; the target Room's `needs_cleaning` was already true and stays true, so there's no partial credit to revert.
- **Kitchen**: `Station.IDS` includes it and `GameState.stations["kitchen"]` is tracked exactly like the other three, but nothing reads a kitchen assignment/skill yet — left for ticket 09.

New tests: `tests/test_roster_station.gd` (extends `sim_test_base.gd`, following `test_manual_seating.gd`'s conventions) cover the Roster's skill data, default coverage, assign/reassign (including the unknown-id false-return case and the Housekeeping mid-job interrupt leaving a second Staffer's job untouched), and all three measurable degradation checkboxes.

Verification note: this environment's vendored `Godot_v4.4-stable_win64_console.exe` still can't run the GUT suite (same pre-existing 4.4-vs-4.7 gap prior tickets documented) -- verified instead via a two-axis `/code-review` (Standards + Spec, both clean, no hard violations or spec gaps) plus a headless `--batch=10` smoke run (`main.gd`'s batch mode) exercising the new per-tick housekeeping/check-in logic across 2,400 ticks with no errors. Standards review flagged three repeated `GameState.balance.get("stations", {}).get(id, {})` lookups as minor Duplicated Code; fixed by extracting `Sim._station_balance(station_id)`. A `test_roster_station.gd`-vs-`test_manual_seating.gd` `_inject_party`/`_party_by_id` duplication was also flagged but left as-is (matches the existing per-file-helper convention; only two occurrences).
