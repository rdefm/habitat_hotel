# The building becomes a Node2D world framed by a Camera2D

Status: accepted, supersedes ADR-0016 (the Control-tree "spatial building cross-section") and the still-open half of ADR-0018 (the auto-scroll-during-drag patch, never implemented, is superseded rather than executed).

ADR-0016 drew Reception, the Terrace, and Room Floors as a vertically-scrolling stack of `Control`/`Button` panels and named it a "spatial building cross-section" — structurally true, but nothing in it is actually drawn: every object is a styled `Button`, and the three screen-space overlay layers (`room_occupancy_layer.gd`, `staff_job_travel_layer.gd`, `toast_layer.gd`, ~850 lines combined) exist only to re-derive world positions from `get_global_rect()` and tween against a full-rect Control on top of that box-model layout. ADR-0018 correctly diagnosed the resulting bug — a Godot GUI drag cannot scroll the container it started in, so a Party dragged from Reception can never reach a Room floor once the building overflows the viewport — named the pan/zoom camera rewrite as the real fix, and then deliberately deferred it in favor of a smaller auto-scroll patch. That patch was never implemented, and the underlying complaints ADR-0018 quoted verbatim ("still reads as a menu, not a visual interface", "can't see the whole hotel in one view") stayed open.

## Decision

**The building becomes a real 2D scene.** `ui/hotel_world.gd`, a `Node2D`, replaces `ui/hotel_view.gd`'s `ScrollContainer` stack: it composes ticket 03's sliced shell art bottom-to-top (ground plinth, Reception's lobby band, the Terrace band at Level 1, one band per unlocked Room type in ascending unlock-Star order, a roofline cap) and frames it with a `Camera2D` that defaults to fit-all bounds, pans on drag, zooms on scroll/pinch within clamped bounds, and eases back to fit-all on command. Floor ordering, level numbering, band composition and the fit-all bounds are derived by a new pure module, `sim/building_layout.gd` — a `RefCounted` of static functions with no node or autoload dependencies, mirroring `sim/match_hint.gd`'s shape — so the renderer draws what that module decided rather than deciding anything itself. This is the seam later tickets (05's anchor registry, 08's bay/Build-Slot content) extend.

**Control survives for the HUD and the modals, moved into a `CanvasLayer`.** `main_screen.gd`'s top bar (Cash/Hearts/Reputation/Star/Day/Season, Pause/1x/2x, and a new "Fit All" button), the generic modal overlay, and `PopupHost` now live in a `CanvasLayer` sibling of the world, since a `Camera2D`'s transform applies to every `CanvasItem` in its viewport that *isn't* shielded behind one — without this, panning or zooming the building would pan and zoom the HUD text right along with it.

**A development toggle keeps both views runnable.** `main_screen.USE_HOTEL_WORLD` (a `const bool`) selects the new world or the old Control stack; both stay wired to the same `GameState`/`Sim` autoloads with no signature changes on either side. This is deliberately a source-level flag, not a settings toggle — it exists for the length of the migration (tickets 04-16) and is deleted along with the old view in ticket 17, per the spec's staged-migration plan.

**The viewport becomes portrait**, roughly 720×1280, `canvas_items` stretch with `expand` aspect, so a desktop window letterboxes rather than reflows the layout — the building is authored for a phone-shaped frame.

## Considered Options

- **Implement ADR-0018's auto-scroll patch instead (rejected)** — the option ADR-0018 itself chose at the time. Keeps the Control-tree architecture entirely, but does not fix "see the whole hotel in one view" or "reads as a menu, not a visual interface", which were the loudest complaints; still needs its own per-target Control-drag wiring, work that would be discarded the moment a camera rewrite happened anyway.
- **Fixed-fit scaling (rejected)** — scale the whole building down to always fit the viewport, so nothing scrolls. Cheaper than a camera, but floors and actors shrink as the hotel grows, eventually hurting drop-target hit-area and readability; never lets a player zoom in for detail.
- **Node2D world + Camera2D (chosen)** — the option ADR-0018 named and deferred. Larger up-front cost (this ticket plus tickets 05-09 to reach interactive parity with the old view), but is the only option that fixes both named complaints and removes the ~850 lines of hand-rolled world-position simulation the three overlay layers exist for.

## Out of Scope

- Interior bay content (guests, staff, Build Slots, the elevator) and interactivity (tap/drag to seat, staff, build) — the world only draws the shell, the floor signs, and the sky-tint in this ticket. Tickets 05-09 add the rest.
- The anchor registry (per-band standing positions) and the placeholder-fallback rule for missing character/interior art — ticket 05.
- Any `Sim`/`GameState` behavior change. Every existing call keeps its exact signature; this is presentation-layer only, the same boundary ADR-0016 drew.
- Deleting the old view and this ticket's toggle — ticket 17, once the world reaches interactive parity.
