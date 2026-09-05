# 16 — Retire the old view and the toggle

**What to build:** The world is the game's only play surface. The development toggle and the entire Control-tree view come out in one change — keeping the toggle any longer would mean maintaining two view trees against every future `GameState` change.

Deleted: `hotel_view.gd`, `hotel_panel.gd`, `reception_panel.gd`, `station_panel.gd`, `terrace_panel.gd`, `staffer_card.gd`, `station_card.gd`, `room_occupancy_layer.gd`, `staff_job_travel_layer.gd`, and the Control-space parts of `toast_layer.gd` — roughly 2,000 lines whose reason to exist was hand-rolling world positioning inside a box-model layout.

ADR bookkeeping closes here: ADR-0016 and ADR-0018 are superseded, ADR-0015 closed, and `CONTEXT.md` reflects the world's vocabulary where the old view's terms leaked into it.

**Blocked by:** 07, 08, 09, 11, 12, 13, 14, 15, 16

**Status:** ready-for-agent

- [ ] The toggle is gone and the world is the only play surface
- [ ] Every listed script is deleted, with no dangling preloads or signal connections
- [ ] The full game loop — arrive, seat, stay, dine, clean, check out, build, staff — is playable end to end in the world
- [ ] The test suite is green
- [ ] ADR-0016 and ADR-0018 are marked superseded and ADR-0015 closed
