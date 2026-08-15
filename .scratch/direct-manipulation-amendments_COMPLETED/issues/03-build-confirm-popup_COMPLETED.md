# 03 — Build Slot tap shows a bespoke build-confirm popup

**What to build:** Tapping a Build Slot opens a small bespoke popup to confirm construction, instead of the current generic-overlay `BuildMenu`.

**Blocked by:** 01 (Bespoke popup host)

**Status:** done

- [x] Tapping a Build Slot opens a bespoke popup (not the generic overlay) showing the Room type's cost, capacity, and upkeep
- [x] The forecast / recently-turned-away-species context currently shown in `BuildMenu` is still available in the popup
- [x] Confirming builds the room exactly as today (`GameState.build_room`); cancelling closes without building
- [x] Uses the popup host from ticket 01

## Comments

`ui/build_confirm_menu.gd` (`BuildConfirmMenu`, `extends VBoxContainer`) is the new bespoke popup, styled like `stay_info_menu.gd`/`seat_confirm_menu.gd`: a room-info label (name, tags, capacity, upkeep, rate), the same forecast and "recently turned away" labels `BuildMenu` used to show, and a "Build (N cash)" / "Cancel" button row. `resolved(built: bool)` mirrors `SeatConfirmMenu`'s `resolved(seated)` shape -- `true` if `GameState.build_room()` ran and succeeded, `false` on cancel.

`main_screen.gd`'s `_on_hotel_slot_selected()` now opens `BuildConfirmMenu` via `_popup_host.open_popup()` for the `instance_id == -1` (Build Slot) branch instead of the generic overlay's `BuildMenu`; the `resolved` handler closes the popup and refreshes `_hotel_panel` only when `built` is true, mirroring `SeatConfirmMenu`'s "only refresh where something actually changed" convention -- a cancel leaves the grid as-is. The occupied/vacant-Room branches are untouched.

The old `ui/build_menu.gd` (and its `BuildMenu` class/generic-overlay usage) is deleted -- nothing else referenced it.

Verified via a full headless load of `main.tscn` (`Godot_v4.4-stable_win64_console.exe --headless --path . --quit-after 2`), showing no new script errors versus the same pre-existing "String formatting error" boot noise ticket 02 noted (unrelated). No GUT test added, following the same no-UI-test precedent as tickets 01/02 -- `GameState.build_room` itself is untouched and already covered by `tests/test_build_room.gd`.
