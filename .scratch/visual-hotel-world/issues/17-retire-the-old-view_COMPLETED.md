# 16 — Retire the old view and the toggle

**What to build:** The world is the game's only play surface. The development toggle and the entire Control-tree view come out in one change — keeping the toggle any longer would mean maintaining two view trees against every future `GameState` change.

Deleted: `hotel_view.gd`, `hotel_panel.gd`, `reception_panel.gd`, `station_panel.gd`, `terrace_panel.gd`, `staffer_card.gd`, `station_card.gd`, `room_occupancy_layer.gd`, `staff_job_travel_layer.gd`, and the Control-space parts of `toast_layer.gd` — roughly 2,000 lines whose reason to exist was hand-rolling world positioning inside a box-model layout.

ADR bookkeeping closes here: ADR-0016 and ADR-0018 are superseded, ADR-0015 closed, and `CONTEXT.md` reflects the world's vocabulary where the old view's terms leaked into it.

**Blocked by:** 07, 08, 09, 11, 12, 13, 14, 15, 16

**Status:** done

- [x] The toggle is gone and the world is the only play surface
- [x] Every listed script is deleted, with no dangling preloads or signal connections
- [x] The full game loop — arrive, seat, stay, dine, clean, check out, build, staff — is playable end to end in the world
- [x] The test suite is green
- [x] ADR-0016 and ADR-0018 are marked superseded and ADR-0015 closed

## Comments

`main_screen.gd`'s `USE_HOTEL_WORLD` toggle and `_build_old_hotel_view()` are gone; `HotelWorld` is mounted unconditionally. All ten listed files are deleted, plus `ui/actor_style.gd` (its only two callers were among the ten). `ui/terrace_menu.gd`'s Kitchen staffing inlines the `StafferCardButton`/`StationCardButton` widgets that used to live in `staffer_card.gd`/`station_card.gd`, since it was their only other caller. `toast_layer.gd` keeps only its world-anchor system, dropping the Control-mode branch.

Reception's admin modal (Prices/Hire/Reports/Reviews) had no equivalent tap gesture in the world yet, since `reception_panel.gd`'s own button was its only entry point — `spec.md`'s "every existing modal survives" covers it, so `ui/hotel_world.gd` gained a `reception_tapped` signal mirroring `terrace_tapped`, backed by a new `RECEPTION_SIGNAGE_RECT_LOCAL`/`resolve_reception_signage_rect()` tap rect in `sim/building_layout.gd` (tested in `tests/test_anchor_registry.gd`), wired in `main_screen.gd`.

ADR-0016 and ADR-0018 are marked superseded by ADR-0020; ADR-0015 was already closed by a prior ticket.

GUT: 249/261 passing, same 12 pre-existing failures (unrelated economy/checkout logic) as on the branch before this change — confirmed via `git stash`. Playtested live via the godot-ai MCP plugin: Reception tap opens `ReceptionMenu`, Terrace tap opens Kitchen staffing with the inlined tap-select/tap-assign gesture working, and a Build Slot tap opens the build-confirm popup — all against the world with no old view left to fall back to.

`/code-review` (standards + spec, run in parallel) found two stale comments left behind by the sweep (`ui/hud_strip.gd`, `ui/staffer_detail_menu.gd`, both still naming retired files/the toggle) — fixed in a follow-up commit. No other hard violations, no missing/partial spec requirements, no unjustified scope creep.
