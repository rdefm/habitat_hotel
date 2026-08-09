# 07 — Drag-and-drop: Party → Room seating

**What to build:** Dragging a Party card from Reception onto a Room seats them, as a second gesture coexisting with the existing tap-Party/tap-Room flow.

**Blocked by:** 01 (drop onto an amber-match Room reuses the bespoke seat-confirm popup)

**Status:** ready-for-agent

- [ ] Dragging a Party card from Reception onto a Room attempts to seat them there, using the same `Sim.match_hint()` rules the tap flow uses (green = seat immediately, amber = confirm popup, none = drop rejected)
- [ ] Tap-Party-then-tap-Room continues to work unchanged alongside the new drag gesture
- [ ] Dropping on a green-match Room seats immediately via `Sim.seat_party()`, matching the tap path's outcome
- [ ] Dropping on an amber-match Room opens the ticket-01 bespoke seat-confirm popup, same as the tap path
- [ ] A rejected drop (invalid target: none-match, a Build Slot, or outside the grid) gives visual feedback that the drop failed and makes no state change
