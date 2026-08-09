# 08 — Roster & Station UI

**What to build:** A Roster view listing each Staffer with their Skill at each Station. Tapping a Staffer then tapping a Station assigns or reassigns them there, following the same direct-manipulation model as seating and building (ADR-0001/0005).

**Blocked by:** 07

**Status:** done

- [x] All three Staffers are listed with their four Station skill ratings visible
- [x] Tapping a Staffer then a Station assigns them there and the view reflects the new assignment
- [x] Reassigning a Staffer already at a Station moves them and the view reflects the interruption (e.g. a dirty room shown as dirty again)

## Comments

New file `ui/roster_menu.gd` (`RosterMenu`, opened as a menu overlay like `BuildMenu`/`UpgradeMenu`/`HireMenu`): mirrors `reception_panel.gd`/`hotel_panel.gd`'s tap-X-then-tap-Y pattern rather than reusing either directly, since Stations aren't spatial world objects the way Rooms are -- there's no "hotel grid" for them to live on. A Staffer row (`_make_staffer_card`, one `Button` per `GameState.staffers` entry, sorted by id) shows the name, an `R# B# H# K#` skill summary, and current Station; tapping toggles selection. A Station row (`_make_station_card`, one per `Station.IDS`) shows the Station name and every currently-assigned Staffer's name (`GameState.station_staffers`); a card is disabled whenever no Staffer is selected, since -- unlike a Room cell -- a Station has no fallback action to offer an unselected tap. Tapping an enabled Station card calls `Sim.assign_staffer(selected_staffer_id, station_id)` (the sole reassignment path, per ticket 07) and clears the selection, so every assignment is a fresh tap-Staffer-then-tap-Station gesture, matching Reception's seat-then-clear flow (`main_screen._finish_seating_flow`).

The third checkbox (reassignment interruption reflected in the view) resolves through the existing generic overlay: `main_screen.close_menu()` already calls `_hotel_panel.refresh()` on every menu close, so a Room a reassigned Housekeeper was mid-cleaning reverts to (and keeps showing as) dirty once the Roster menu is closed, without any new wiring in `roster_menu.gd` itself -- ticket 07 already guarantees the underlying `needs_cleaning` state stays true.

Folded the old `ui/staff_menu.gd` Chunk-2 stub (flat daily-wage placeholder text) into `RosterMenu`'s footer and deleted the stub file; repointed `main_screen.gd`'s menu bar entry from "Staff" -> "Roster" (`RosterMenu`), and fixed the one string in `ui/hire_menu.gd` that referenced "the Staff menu" by name.

Verification note: this environment's vendored `Godot_v4.4-stable_win64_console.exe` still can't run the GUT suite (same pre-existing 4.4-vs-4.7 gap prior tickets documented), and there's no established GUI-driving setup in this environment to click through the actual window (unlike a browser/Electron app, headless Godot has no `xvfb`-equivalent input-injection path wired up here). Same situation ticket 03/05 hit for their UI-only work. Verified via a headless `--verify` run (2,400+ ticks, main_screen/RosterMenu scripts parse and load cleanly, no new errors versus the pre-existing baseline of 12 unrelated `String formatting error` warnings already present on `HEAD`) plus a two-axis `/code-review` (Standards + Spec) against the uncommitted diff: Standards axis found zero hard violations (one minor Duplicated Code judgement call -- the skill-rating string was built twice for `btn.text`/`tooltip_text` -- fixed by extracting `_skill_summary()`; the `STATION_LABELS` dict needing manual upkeep alongside `Station.IDS` was noted but left as-is, since no data-driven Station name field exists to read from instead). Spec axis found all three checklist items satisfied, no missing/partial requirements, no implementation bugs, and judged the Staff-menu deletion/rename as in-service cleanup rather than scope creep.
