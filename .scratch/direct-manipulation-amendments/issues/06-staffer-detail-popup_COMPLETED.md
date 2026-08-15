# 06 — Staffer tap opens a bespoke detail popup; Roster menu retired

**What to build:** Tapping any Staffer, at their Reception-area or Terrace placement, opens a bespoke popup with their per-Station Skill, Traits, and current assignment. With both of the Roster menu's former jobs (assignment, info) now living elsewhere, the Roster menu is deleted entirely.

**Blocked by:** 01 (Bespoke popup host), 04 (Reception-area Staffer placement), 05 (Terrace/Kitchen Staffer placement)

**Status:** done

- [x] Tapping any Staffer (at Reception-area Stations or the Terrace's Kitchen slot) opens a bespoke popup showing their Skill rating at each of the four Stations, their Traits, and their current assignment
- [x] The popup uses the popup host from ticket 01
- [x] The "Roster" menu-bar entry and `roster_menu.gd` are removed entirely
- [x] Every Staffer previously visible in the Roster menu remains reachable and tappable from their new Station placement — no Staffer becomes inspectable-only-via-code

## Comments

`ui/staffer_detail_menu.gd` (`StafferDetailMenu`, `extends VBoxContainer`) is the new bespoke popup: name header, Skill at each of the four Stations (`sim/station.gd`'s `Station.IDS`/`LABELS`), a Traits section (reads `staffer.get("traits", [])` defensively -- no Staffer carries one yet, since ADR-0013's per-Staffer Trait assignment is a separate, unimplemented ticket), and current assignment via `GameState.staffer_station()`. `signal closed` mirrors the other bespoke popups' `resolved(...)` shape but has no branch to report, since there's no follow-up action beyond closing.

Resolving the tension between ADR-0009 (tap-Staffer/tap-Station remains the interaction model; drag-and-drop is a later, second, coexisting gesture -- ticket 08, not yet built) and this ticket's "tapping any Staffer opens a popup": `ui/station_panel.gd` and `ui/terrace_menu.gd`'s existing `_on_staffer_pressed` still toggles `_selected_staffer_id` exactly as before (so tap-Station-to-assign, built in tickets 04/05, keeps working once the popup is closed), and now *also* emits a new `staffer_tapped(staffer_id)` signal that `main_screen.gd` uses to open the detail popup via `PopupHost`. A single tap does both -- selects for assignment and shows detail -- rather than replacing one gesture with the other.

For the Terrace's Kitchen slot, the popup opens on top of the already-open generic overlay (`TerraceMenu`, opened via `open_menu()`), since `PopupHost` is added to `main_screen.gd`'s tree after the overlay and so renders above it. `PopupHost.close_popup()` unconditionally resumes the Clock, which would incorrectly un-pause a still-open `TerraceMenu` underneath -- `main_screen._on_staffer_tapped()`'s `closed` handler re-pauses the Clock if `_overlay.visible` after closing the popup, avoiding that regression (caught by the Spec-axis `/code-review` pass before commit).

`ui/roster_menu.gd` is deleted; its menu-bar entry and `RosterMenu` preload are removed from `main_screen.gd`. `ui/hire_menu.gd`'s stale "(see the Roster menu)" reference (the flat daily wage note) now points at "the Station panel near Reception", where `ui/station_panel.gd` already shows that line.

Verified via a full headless load of `main.tscn` (`godot --headless --path . --quit-after 2`), showing no new script errors versus the established pre-existing "String formatting error" boot noise (unchanged since ticket 01/02). GUT still doesn't run in this sandbox's Godot 4.4 binary (confirmed again, same as prior tickets), so no GUT test was added, following the same no-UI-test precedent as tickets 01-05.
