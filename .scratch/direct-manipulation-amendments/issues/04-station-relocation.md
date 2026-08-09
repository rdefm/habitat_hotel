# 04 — Reception/Bellhop/Housekeeping Station slots move out of the Roster menu

**What to build:** Reception, Bellhop, and Housekeeping Station slots become always-visible near Reception in the main hotel view, mirroring the reference prototype's layout, instead of living inside the Roster menu.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] Reception, Bellhop, and Housekeeping Station slots are always visible near Reception in the main view, not gated behind opening the Roster menu
- [ ] Tapping a Staffer then tapping one of these three Station slots (re)assigns them, using the same `Sim.assign_staffer()` call and interruption semantics `roster_menu.gd` uses today
- [ ] `roster_menu.gd` no longer renders these three Station cards or handles their assignment
- [ ] Reassigning a Staffer mid-task still interrupts only that Staffer's job (existing behavior preserved)
- [ ] The crew's flat daily wage info (currently shown in the Roster menu) is still visible somewhere in the new layout
