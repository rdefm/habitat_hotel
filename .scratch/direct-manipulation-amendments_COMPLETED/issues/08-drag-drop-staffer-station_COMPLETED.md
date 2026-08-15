# 08 — Drag-and-drop: Staffer → Station assignment

**What to build:** Dragging a Staffer onto any of the four Station slots (Reception/Bellhop/Housekeeping near Reception, Kitchen on the Terrace) assigns/reassigns them, as a second gesture coexisting with tap-Staffer/tap-Station.

**Blocked by:** 04 (Reception-area Station slots), 05 (Kitchen's Station slot on the Terrace)

**Status:** done

- [x] Dragging a Staffer onto any of the four Station slots calls `Sim.assign_staffer()`, same as the tap-Staffer/tap-Station gesture
- [x] Tap-Staffer-then-tap-Station continues to work unchanged alongside the new drag gesture
- [x] Reassigning a Staffer mid-task via drag interrupts only that Staffer's in-flight job (a Housekeeping job reverts its Room to dirty; a Kitchen job returns its guest/diner to waiting), matching the tap path's behavior
- [x] A drop outside any Station slot is a no-op with visual feedback that the drop failed

## Comments

`ui/staffer_card.gd` gains `StafferCardButton` (a nested `Button` subclass, mirroring ticket 07's `PartyCardButton`) as the drag source: `_get_drag_data()` returns `{"type": "staffer", "staffer_id": ...}` with a text-matching preview, and flashes red on `NOTIFICATION_DRAG_END` when `gui_is_drag_successful()` is false. `ui/station_card.gd` gains `StationCardButton` (mirroring `RoomCellButton`) as the drop target: `_can_drop_data()` accepts any `"staffer"`-typed payload (there's no Party/Room-style match_hint to reject on -- any Staffer is a valid drop on any Station, same as the tap path), and `_drop_data()` emits a local `staffer_dropped` signal wired in `StationCard.make_button()` to the exact same `Sim.assign_staffer(...)` + `on_assigned.call()` pair the tap-Staffer-then-tap-Station flow already used -- so both gestures share one call site by construction.

Since `StafferCard`/`StationCard` are shared between `ui/station_panel.gd` (Reception/Bellhop/Housekeeping) and `ui/terrace_menu.gd` (Kitchen), patching the two shared widgets covers all four Station slots in one change; neither panel file needed touching.

Interruption semantics (checklist item 3) needed no new code: drag and tap both route through the identical `Sim.assign_staffer()` in `autoload/sim_controller.gd`, which already has full characterization coverage in `tests/test_roster_station.gd` (e.g. `test_reassigning_a_housekeeper_mid_job_reverts_only_their_room_leaving_others_untouched`).

A Station card's own `disabled` state (gating the tap flow while no Staffer is tap-selected) doesn't block Godot's drop hit-testing, so a drag-drop works regardless of tap-selection -- confirmed by reading Godot's drag/drop dispatch, not just assumed.

Verified via a full headless load of `main.tscn` (`godot --headless --path . --quit-after 2`), showing the same pre-existing baseline error count (4, unrelated `String formatting error`s) as ticket 07's report -- zero new errors. No GUT-based test was added, following ticket 07's precedent: GUT still doesn't load in this sandbox's Godot 4.4 binary, and this repo has no UI-level tests for `ui/*_panel.gd`/`ui/*_menu.gd` files.
