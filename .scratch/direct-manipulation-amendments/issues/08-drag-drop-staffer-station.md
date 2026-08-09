# 08 — Drag-and-drop: Staffer → Station assignment

**What to build:** Dragging a Staffer onto any of the four Station slots (Reception/Bellhop/Housekeeping near Reception, Kitchen on the Terrace) assigns/reassigns them, as a second gesture coexisting with tap-Staffer/tap-Station.

**Blocked by:** 04 (Reception-area Station slots), 05 (Kitchen's Station slot on the Terrace)

**Status:** ready-for-agent

- [ ] Dragging a Staffer onto any of the four Station slots calls `Sim.assign_staffer()`, same as the tap-Staffer/tap-Station gesture
- [ ] Tap-Staffer-then-tap-Station continues to work unchanged alongside the new drag gesture
- [ ] Reassigning a Staffer mid-task via drag interrupts only that Staffer's in-flight job (a Housekeeping job reverts its Room to dirty; a Kitchen job returns its guest/diner to waiting), matching the tap path's behavior
- [ ] A drop outside any Station slot is a no-op with visual feedback that the drop failed
