# 07 — Drag-and-drop: Party → Room seating

**What to build:** Dragging a Party card from Reception onto a Room seats them, as a second gesture coexisting with the existing tap-Party/tap-Room flow.

**Blocked by:** 01 (drop onto an amber-match Room reuses the bespoke seat-confirm popup)

**Status:** done

- [x] Dragging a Party card from Reception onto a Room attempts to seat them there, using the same `Sim.match_hint()` rules the tap flow uses (green = seat immediately, amber = confirm popup, none = drop rejected)
- [x] Tap-Party-then-tap-Room continues to work unchanged alongside the new drag gesture
- [x] Dropping on a green-match Room seats immediately via `Sim.seat_party()`, matching the tap path's outcome
- [x] Dropping on an amber-match Room opens the ticket-01 bespoke seat-confirm popup, same as the tap path
- [x] A rejected drop (invalid target: none-match, a Build Slot, or outside the grid) gives visual feedback that the drop failed and makes no state change

## Comments

`ui/reception_panel.gd` gains `PartyCardButton` (a nested `Button` subclass) as the drag source: `_get_drag_data()` returns `{"type": "party", "party_id": ...}` and sets a text-matching preview. `ui/hotel_panel.gd` gains `RoomCellButton` as the drop target: `_can_drop_data()` runs the real `Sim.match_hint()` check (rejecting Build Slots and `"none"` outright, not just a type check), and `_drop_data()` emits a local `drop_attempted` signal that `_on_cell_dropped()` forwards straight into the existing `seat_attempted` signal -- the same one `_on_cell_pressed()` already emits for the tap flow. `main_screen.gd`'s `_on_seat_attempted()` is untouched in its branching, so green/amber routing (`Sim.seat_party()` directly vs. the ticket-01 `SeatConfirmMenu` popup) is identical for both gestures by construction.

Rejected-drop feedback doesn't rely on figuring out Godot's exact `_can_drop_data` hit-testing/bubbling rules: `PartyCardButton` instead watches its own `NOTIFICATION_DRAG_END` (guarded by a local `_dragging` flag, since that notification isn't scoped to the drag's source) and checks `get_viewport().gui_is_drag_successful()`, flashing red via a `create_tween()` (matching `ui/lobby_view.gd`'s existing tween idiom) whenever the drop failed for *any* reason -- Build Slot, none-match, or dropped entirely outside the grid all look the same from here: no `_drop_data` call anywhere, so the drag was unsuccessful.

Fixed a real bug the drag gesture exposed in `main_screen.gd`'s `_on_seat_attempted()`: it read `dinner_addon` from `_reception_panel.dinner_addon_selected`, which reflects the *tap-selected* Party's checkbox. Since a drop's `party_id` now travels independently of tap-selection, dragging a different Party than whichever one (if any) is tap-selected would have silently applied the wrong Party's dinner-addon flag. Fixed by falling back to the dragged Party's own persisted `Sim.pending_party(party_id).dinner_addon` whenever `party_id` isn't the currently tap-selected one -- the same seeding `reception_panel.gd`'s `_on_card_pressed()` already does when a card is selected.

Verified via a full headless load of `main.tscn` (`godot --headless --path . --quit-after 2`) showing the same pre-existing baseline error count (4, unrelated `String formatting error`s) as a clean stash of the working tree -- zero new errors from this change. No GUT-based test was added, following ticket 01's precedent: this repo has no UI-level tests for `ui/*_panel.gd`/`ui/*_menu.gd` files (pure UI wiring, characterized by class doc rather than tests), and GUT itself still doesn't load in this sandbox's Godot 4.4 binary (confirmed unchanged from ticket 01).
