# 02 — Occupied-Room tap shows a bespoke stay-info popup

**What to build:** Tapping a built, occupied Room (with no Party selected at Reception) opens a small bespoke popup with that stay's details, instead of jumping straight into the Upgrade menu.

**Blocked by:** 01 (Bespoke popup host)

**Status:** done

- [x] Tapping a built, occupied Room (no Party selected) opens a bespoke popup showing the guest's name, species, fit (perfect fit / mismatch), and dinner add-on status
- [x] The popup offers a way to reach the existing Upgrade menu from there, so upgrade/price flows aren't lost
- [x] Tapping a built, occupied Room no longer opens the Upgrade menu directly
- [x] Tapping a built, vacant Room (no Party selected) still opens the Upgrade menu directly, unchanged
- [x] Uses the popup host from ticket 01

## Comments

`ui/stay_info_menu.gd` (`StayInfoMenu`, `extends VBoxContainer`) is the new bespoke popup, styled like `seat_confirm_menu.gd`: guest name, species, fit, and dinner add-on line, plus an "Upgrade Room" and a "Close" button. `resolved(open_upgrade: bool)` mirrors `SeatConfirmMenu`'s `resolved(seated)` signal shape.

`main_screen.gd`'s `_on_hotel_slot_selected()` now branches on `room["occupant"] != null` for a built room: occupied opens `StayInfoMenu` via `_popup_host.open_popup()`; vacant falls through to a new `_open_upgrade_menu()` helper (the same `UpgradeMenu` construction that used to run unconditionally for any built room, now shared by both the vacant path and the popup's "Upgrade Room" button). The Build path (`instance_id == -1`) is untouched.

Verified via a full headless load of `main.tscn` (`godot --headless --path . --quit-after 2`), showing no new script errors versus a stashed baseline (the pre-existing "String formatting error" lines are unchanged, unrelated boot noise). No GUT test added, following the same no-UI-test precedent as ticket 01 -- this repo has no UI-level tests for any `ui/*_menu.gd` file.
