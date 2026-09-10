# Auto-scroll during drag; ADR-0015 (Manny) finally implemented

Status: superseded by ADR-0020, whose own status line already noted this: "the still-open half of ADR-0018 (the auto-scroll-during-drag patch, never implemented, is superseded rather than executed)" — ticket 17 then deleted HotelView itself. Closes ADR-0015 (previously accepted, never implemented), which stands: Manny's real animation survived the rewrite, resolved through `sim/building_layout.gd`'s `resolve_character_sprite()` instead of the Control-tree path this ADR originally wired it into (was: accepted, amends ADR-0016; closes ADR-0015).

Playtesting surfaced two real bugs. (1) HotelView's vertical scroll stack (ADR-0016) has no auto-scroll during a Godot GUI drag, so a Party dragged from Reception (bottom of the stack) can never reach a Room floor (top of the stack) once the building overflows the viewport — the drag gesture physically cannot cross out-of-view space, and the same likely applies to Staffer→Station drags once the Station row/Staff Pool scroll off-screen. (2) ADR-0015 (rename Staffer `marlon` to `manny`, give him real sprite animation) was accepted but never actually implemented: `data/staffers.json`, `autoload/game_state.gd`, and every test still say `marlon`/`Marlon`. `assets/Manny-walk.png`/`Manny-sweeping.png` are imported into the project, but no `.gd` file references them — Manny still renders as `ActorStyle.flat_box()` like every other placeholder actor.

## Decision

**Drag-and-drop**: HotelView gets auto-scroll while a GUI drag is in progress — scroll the ScrollContainer when the pointer nears the top/bottom edge during any drag whose payload is `{"type": "party"}` or `{"type": "staffer"}`, the same pattern list-reorder UIs commonly use. This is a scoped patch, not a redesign: the vertical-scroll-stack layout ADR-0016 established is kept as-is.

**Manny**: ADR-0015 is executed for real. Staffer id `marlon` → `manny` everywhere (data/staffers.json, GameState, every Sim/test reference) — a hard rename, no back-compat alias, since a Staffer id is only ever referenced by string key internally and is never persisted externally today. Manny's actor token gets a real `AnimatedSprite2D`/`AnimationPlayer` driven by his current task (walk between Stations, sweep while cleaning), exactly as ADR-0015 specified, wired into whichever presentation path currently renders him as a flat shape (`ui/station_panel.gd`'s Staffer actor, `ui/staff_job_travel_layer.gd`'s travel animation, `ui/room_occupancy_layer.gd`'s occupant token). Every other Staffer and Guest stays a plain colored shape, unchanged.

## Considered Options (view model)

Three ways to make drag-and-drop always reachable were on the table:

- **Pan/zoom camera** — move the building to a real Node2D/Camera2D world so the player can zoom out to see (and drag across) the whole hotel at once. Would also resolve "can't see the whole hotel in one view" and the "still reads as menus, not a visual interface" complaint (real sprites instead of styled Buttons), but is a full rewrite of the Control-tree UI onto a 2D world.
- **Fixed-fit scaling** — scale the whole building down to always fit the viewport, so nothing ever scrolls. Cheaper than a camera, but floors and actors shrink as the hotel grows, eventually hurting drop-target hit-area and readability.
- **Auto-scroll during drag (chosen)** — smallest change; keeps today's Control-tree/ScrollContainer architecture entirely. Chosen deliberately over the other two even though it does **not** fix "see the whole hotel in one view" or the underlying "still reads as a menu, not a visual interface" complaint — those stay open, deferred by explicit choice, not oversight.

## Out of Scope

- The whole-hotel-in-one-glance view and the real-sprite/"visual interface, not menus" rework (guests and every Staffer besides Manny) — explicitly deferred. A future ADR should revisit the pan/zoom camera option above if/when that work is prioritized.
- The reported Staffer→Station drag failure: `staffer_card.gd`/`station_card.gd`'s `get_drag_data`/`can_drop_data`/`drop_data` wiring reads as correct on inspection, so this needs a live repro before it's diagnosed as a duplicate of the auto-scroll bug above or a separate defect — not an architecture decision, left as an open question for the next ticket pass.
- Any Sim/GameState behavior change — this is presentation-layer only, the same boundary ADR-0016 already drew.
