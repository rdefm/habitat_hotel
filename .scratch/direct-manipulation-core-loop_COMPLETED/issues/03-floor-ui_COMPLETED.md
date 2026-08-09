# 03 — Floor UI

**What to build:** The always-visible hotel view renders each unlocked Room type as its own Floor (a row of that type's built instances) with a Build Slot at the end of the row whenever that Floor is under its instance cap; Floors for not-yet-unlocked Room types stay hidden. Tapping a Build Slot opens the existing scoped build flow (forecast, recently-turned-away, cash-permitting construction) for that Floor; tapping any already-built room on any Floor still opens its Upgrade menu unchanged.

**Blocked by:** 02

**Status:** done

- [x] The hotel view shows one row per unlocked Room type, not a flat generic grid
- [x] A Build Slot appears at the end of a Floor's row only while that Floor is under its instance cap, and disappears once the cap is reached
- [x] A locked Floor (Room type not yet star-unlocked) is not shown
- [x] Tapping a Build Slot opens the build flow scoped to that Floor's Room type, with construction still instant on confirming
- [x] Tapping a built room on any Floor opens its Upgrade menu exactly as before the rework

## Comments

`ui/hotel_panel.gd` changed from a flat `GridContainer` to a `VBoxContainer` of per-Floor rows: `refresh()` now emits one row (`_make_floor_row`) per unlocked Room type, each an `HBoxContainer` of built-instance cells inside a horizontally-scrolling `ScrollContainer`, with a trailing Build Slot cell while under the instance cap -- same cell rendering and `slot_selected(room_type_id, instance_id)` contract as before, so `main_screen.gd`'s Build/Upgrade dispatch needed no changes.

Verification note: this environment's vendored `Godot_v4.4-stable_win64_console.exe` still can't run the GUT suite (same pre-existing 4.4-vs-4.7 gap ticket 02 documented) -- confirmed again this session (`GutErrorTracker` parse failure). This ticket is pure UI restructuring with no new `GameState`/`SimController` surface, so no new tests were needed per the spec's testing decisions (UI is a thin, untested layer over the sim seam). Verified via a two-axis `/code-review` (Standards + Spec) instead: Spec axis found all five checklist items satisfied with no scope creep beyond a reasonable per-row scroll container; Standards axis found zero hard violations and two minor judgement calls (a duplicated `GameState.rooms[...]` lookup, a bare font-size literal), both fixed before commit.
