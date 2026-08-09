# 09 — Drag-and-drop: Staffer → in-progress Job (Stacking)

**What to build:** Dragging a second Staffer onto a Room mid-clean or a Terrace queue entry being served stacks them onto that Job (ADR-0008), summing Skill up to the existing cap.

**Blocked by:** 08 (Staffer drag-and-drop machinery)

**Status:** ready-for-agent

- [ ] Dragging a second Staffer onto a Room currently mid-clean (a Housekeeping Job) stacks them onto that Job, summing Skill and looking up the combined service time per ADR-0008's rule
- [ ] Dragging a second Staffer onto a Terrace breakfast/dinner queue entry currently being served (a Kitchen Job) stacks them the same way
- [ ] A third drop onto a Job that already has 2 Staffers is rejected: no state change, visual feedback that the drop failed
- [ ] Reception and Bellhop Station slots are not valid Stacking drop targets (no per-target Job exists there), matching ADR-0008
- [ ] Stacking via drag produces the same resulting service time as the existing sum-then-cap-then-lookup formula — no second formula is introduced
