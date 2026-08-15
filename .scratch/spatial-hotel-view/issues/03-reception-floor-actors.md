# 03 — Reception ground floor: queue actors, Station drop-zones, Staff Pool

**What to build:** Replace the party-card list and staffer/station-card rows with actors on the Reception ground floor: every pending arrival renders as a draggable guest actor standing in a queue (drag onto a Room to seat, same match/seat flow; tap-select-then-tap-Room keeps working alongside it), and the Reception/Bellhop/Housekeeping Station drop-zones render as places a Staffer actor can be dropped/tapped-to-assign. Add a new Staff Pool area on this floor listing every currently-unassigned Staffer as an idle, draggable actor (there's no equivalent today). Tapping a Staffer actor still opens their existing detail popup.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Every pending arrival renders as a distinct actor standing in a queue on the Reception floor, in the same order/Patience-tier coloring as today's cards
- [ ] Dragging a guest actor onto a valid Room seats them via the existing seating flow; dragging onto an invalid target is rejected with visible feedback, matching today's reject-flash behavior
- [ ] Tap-selecting a guest actor then tapping a Room still seats them, unchanged from today's tap flow
- [ ] Reception, Bellhop, and Housekeeping each show a distinct drop-zone that accepts a dragged Staffer actor and assigns them, matching today's Station-card behavior
- [ ] Every Staffer with no current Station assignment renders as an idle actor in a new Staff Pool area on this floor
- [ ] Dragging a Staffer actor from the Staff Pool onto a Station assigns them and removes them from the Pool; reassigning a Staffer off a Station returns them to the Pool
- [ ] Tapping any Staffer actor (Station-assigned or in the Pool) opens the existing Staffer detail popup unchanged
