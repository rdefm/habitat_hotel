# 05 — Reception & seating UI, Policy menu removed

**What to build:** Arriving Parties are visible and tappable in a Reception queue, each showing Species and party size at a glance, with a visible Patience state that reads as increasingly urgent (e.g. calm → impatient → huffy) before a Party leaves. Tapping a waiting Party then tapping a Room attempts to seat them there using the match-hint from ticket 04: a green Room seats immediately, an amber Room asks for confirmation and states what Need is missing, and a Room with no highlight does not respond to a tap at all. The Policy menu and its menu-bar entry are removed (ADR-0001).

**Blocked by:** 04, 03

**Status:** done

- [x] Every waiting Party is visible at Reception with its Species and party size shown without opening a detail screen
- [x] A Party's Patience visibly changes state at least once before it would walk away, giving fair warning
- [x] Tapping a Party then a green Room seats them immediately with no extra step
- [x] Tapping a Party then an amber Room shows a confirmation naming the missing Need before seating
- [x] Tapping a Party then a no-highlight Room does nothing
- [x] The Policy menu no longer exists and the menu bar has no Policy entry

## Comments

Implementation was already present on `HEAD` (commit `5628a2e`, "Add Reception queue and tap-to-seat UI, remove Policy menu (ADR-0001)") from a prior session, but this ticket file was never updated to reflect it. This session verified the work against the checklist and closed it out rather than re-implementing.

`ui/reception_panel.gd` (new) renders every `Sim.pending_arrivals` entry as a tappable card (Species + party size + `sim/patience_state.gd`'s calm/impatient/huffy tier), rebuilt on every tick so Patience visibly counts down. `ui/hotel_panel.gd` gained a `selected_party_id`-driven mode: with a Party selected, built-room cells show `Sim.match_hint()`'s green/amber tint (a Build Slot or a "none" cell never responds to a tap), and tapping emits `seat_attempted` instead of the normal Build/Upgrade `slot_selected`. `main_screen.gd` wires the two panels together: green seats immediately via `Sim.seat_party()`, amber opens `ui/seat_confirm_menu.gd` (new) which names the missing Need(s) via `MatchHint.missing_needs()` before seating. `data/balance.json`'s `patience.impatient_at`/`huffy_at` (trimmed as unused in ticket 04) were reintroduced, now genuinely consumed by `sim/patience_state.gd`'s `tier()`. The Policy menu was already deleted in ticket 04; this ticket only needed to confirm no dangling references remained, which it does.

Verification note: this environment's vendored `Godot_v4.4-stable_win64_console.exe` still can't run the GUT suite (confirmed again this session — same pre-existing 4.4-vs-4.7 gap tickets 02-04 documented). Verified via a two-axis `/code-review` (Standards + Spec) against `a1d191b...HEAD` instead. Spec axis: all six checklist items satisfied, no missing/partial requirements, no scope creep (the balance.json reintroduction is load-bearing, not speculative regrowth), no implementation bugs -- `Sim.seat_party()` re-classifies the hint server-side rather than trusting the UI's earlier tap. Standards axis: zero hard violations; three minor judgement calls noted but left as-is (non-blocking, no established convention actually broken): `seat_confirm_menu.gd` re-deriving `GameState.room_instance` → `effective_room_stats` instead of a hypothetical `Sim.missing_needs()` query (though direct `GameState.room_instance()` calls from UI are already an established pattern, e.g. `hotel_panel.gd`'s own `refresh()`); `seat_attempted`'s unused `hint` string param (a bool would do); and `hotel_panel.gd`'s selected-party mode leaving a stale occupant tooltip on already-occupied (no-highlight, non-interactive) cells, which is cosmetic only since the button text already shows occupant info and the tap is correctly a no-op regardless.
