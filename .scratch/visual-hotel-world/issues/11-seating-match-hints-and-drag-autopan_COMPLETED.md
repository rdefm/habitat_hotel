# 10 — Seating: drag, tap-then-tap, Match hints, and drag auto-pan

**What to build:** The seating decision made against the building itself.

Dragging a guest onto a Room bay seats them there; tapping a guest and then tapping a bay does the same, so nobody is forced into a drag they cannot make. Both gestures put the Party into the same selected state, so the Needs bubble and the bay glow appear either way. Bays whose Room satisfies every Need glow green, partial matches glow amber, and unseatable bays do not glow. The existing seat-confirm modal handles the amber case exactly as today.

While a drag is in progress, holding the pointer near the top or bottom of the screen pans the camera at a steady rate, so any floor is reachable from the lobby at any zoom. This is a known trade-off: a long traverse is slow and the target floor is not visible until it scrolls in. If it proves tedious in playtest, easing the camera to fit-all on pickup is the contained alternative — the drag payload and drop-target logic are unaffected either way.

Match hints are not re-derived: the layout model calls the existing `Sim.match_hint()` and surfaces its answer as per-bay render state. ADR-0001 and ADR-0009 are otherwise untouched — tap-then-tap and drag coexist, and there is still no auto-matcher.

**Blocked by:** 08, 10

**Status:** done

- [x] Dragging a guest onto a bay seats the Party there
- [x] Tapping a guest then tapping a bay seats the Party there
- [x] Both gestures show the same Needs bubble and the same bay glows
- [x] Green, amber and no-glow bays match what `Sim.match_hint()` returns, with no hint logic duplicated in the view
- [x] Seating an amber match still routes through the existing seat-confirm modal
- [x] Holding a drag near the top or bottom edge pans the camera, and a lobby-to-top-floor drag is completable at full zoom
- [x] Per-bay Match hint state is covered by tests against the pure layout model

## Comments

Implemented in `sim/building_layout.gd`: `room_bay_match_hint(selected_party_id, room_type_id, instance_id, hint_fn)` is the new seam -- same injectable-probe shape as `resolve_room_interior()`'s `probe_fn` elsewhere in the file, real default calls through to `Sim.match_hint()` (the single existing authority, per ADR-0001), tests inject a literal-returning Callable. `selected_party_id == -1` (nothing tapped/picked up) short-circuits to `"none"` with no call at all. `tests/test_room_match_hint.gd` (5 tests) covers the -1/green/amber/none/arg-forwarding cases against this pure function, same shape as `tests/test_room_bays.gd`.

`ui/room_bay_actor.gd` gained `set_match_hint(hint)`, a translucent green/amber glow overlay applied in place (no `configure()`/subtree teardown) so re-glowing on a selection change doesn't touch occupancy/dirt/upgrade rendering.

`ui/hotel_world.gd` unifies the tap-then-tap and drag gestures around one selection concept: pressing a lobby guest (`_begin_guest_drag()`) always calls `_select_guest()` immediately -- opening the Needs bubble and refreshing every built bay's glow (`_refresh_bay_match_hints()`) -- before release decides whether the press was a tap or a real drag, so ADR-0009's "picking up a Party in a drag puts it into the same selected state a tap produces" holds from the first frame of a potential drag, not just after it resolves. Release either attempts a seat against whatever built bay is under the pointer (`_attempt_seat_drop()`, the drag half) or, if unmoved and the guest was already selected before this press, closes the bubble again (the ticket 10 toggle-shut gesture preserved). The tap-then-tap half reuses the exact same `_tappable_room_bay_at()` hit-test already used for the ordinary build/inspect tap: while a Party is selected, a press on any Room bay is claimed by the seating gesture -- a Build Slot or a "none"-hint Room is consumed with no effect (matching `ui/hotel_panel.gd`'s pre-existing `_on_cell_pressed()` rule under ADR-0001), never falling through to Build/Inspect or being treated as "elsewhere" (which would otherwise close the selection). Both the tap-then-tap and drag call sites resolve their target's hint through `BuildingLayout.room_bay_match_hint()`, never `Sim.match_hint()` directly, so the layout model really is the one seam.

Auto-pan (`_auto_pan_if_near_edge()`, driven from `_process()`) holds for any active drag -- guest or Staffer -- rather than being guest-only: it's the same mechanism either way, and spec.md's Camera-and-drag section licenses it for "a drag with a party or staffer payload." `AUTO_PAN_EDGE_ZONE`/`AUTO_PAN_SPEED` are unverified constants (60px / 500 world-units-per-second at zoom 1), left for playtest tuning per spec.md's Testing Decisions ("camera easing and zoom clamping" are deliberately not unit-tested).

`ui/main_screen.gd` gained `_on_world_seat_attempted()`, a fresh handler for `HotelWorld.party_seat_attempted` rather than reusing the old view's `_on_seat_attempted()` -- that handler reads `_hotel_panel`/`_reception_panel` (the tap-selection state and dinner-addon checkbox), neither of which exists under `USE_HOTEL_WORLD`. Green seats immediately via `Sim.seat_party()`; amber opens the existing `SeatConfirmMenu` unchanged. The world's own selection/Needs-bubble state clears itself on the next rebuild once a seated Party leaves `Sim.pending_arrivals`, so the handler has no cleanup of its own to do.

Full suite: 238 tests, 225 passing, 13 pre-existing failures -- same set prior tickets' runs already confirmed unrelated (day-night-cycle, hotel-background-slices, integration-multiday, manual-seating, room-guest-dinner-addon).
