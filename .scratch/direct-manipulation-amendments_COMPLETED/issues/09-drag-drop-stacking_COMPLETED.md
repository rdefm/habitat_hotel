# 09 — Drag-and-drop: Staffer → in-progress Job (Stacking)

**What to build:** Dragging a second Staffer onto a Room mid-clean or a Terrace queue entry being served stacks them onto that Job (ADR-0008), summing Skill up to the existing cap.

**Blocked by:** 08 (Staffer drag-and-drop machinery)

**Status:** done

- [x] Dragging a second Staffer onto a Room currently mid-clean (a Housekeeping Job) stacks them onto that Job, summing Skill and looking up the combined service time per ADR-0008's rule
- [x] Dragging a second Staffer onto a Terrace breakfast/dinner queue entry currently being served (a Kitchen Job) stacks them the same way
- [x] A third drop onto a Job that already has 2 Staffers is rejected: no state change, visual feedback that the drop failed
- [x] Reception and Bellhop Station slots are not valid Stacking drop targets (no per-target Job exists there), matching ADR-0008
- [x] Stacking via drag produces the same resulting service time as the existing sum-then-cap-then-lookup formula — no second formula is introduced

## Comments

New `Sim` state: `_cleaning_jobs`/`_breakfast_jobs`/`_dinner_jobs` entries are keyed by staffer_id, so two Staffers sharing one Job simply means two dict entries pointing at the same target with the same `ticks_remaining`. `Sim.STACK_CAP` (2) and `Sim.MAX_SKILL` (5) are the shared constants; `_ticks_for_skill_sum()` is the one formula (summed, capped Skill looked up in the same per-Station `*_ticks_by_skill` tables a solo Staffer's Job already uses) that `stack_staffer_on_room()`/`stack_staffer_on_breakfast()`/`stack_staffer_on_dinner()` all call. `_drop_staffer_jobs()` factors out the erase-from-all-three-dicts step shared by `assign_staffer()` and the three `stack_staffer_on_*()` entry points. `RoomCellButton` (`ui/hotel_panel.gd`) and the new `QueueEntryButton` (`ui/terrace_panel.gd`) both dispatch on the drag payload's `type` (`"party"` vs `"staffer"`) to route to seating vs Stacking. Tests in `tests/test_stacking.gd` (extends `sim_test_base.gd`) cover all five checkboxes above across both Housekeeping and Kitchen.
