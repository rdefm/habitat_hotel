# 10 — Seating: drag, tap-then-tap, Match hints, and drag auto-pan

**What to build:** The seating decision made against the building itself.

Dragging a guest onto a Room bay seats them there; tapping a guest and then tapping a bay does the same, so nobody is forced into a drag they cannot make. Both gestures put the Party into the same selected state, so the Needs bubble and the bay glow appear either way. Bays whose Room satisfies every Need glow green, partial matches glow amber, and unseatable bays do not glow. The existing seat-confirm modal handles the amber case exactly as today.

While a drag is in progress, holding the pointer near the top or bottom of the screen pans the camera at a steady rate, so any floor is reachable from the lobby at any zoom. This is a known trade-off: a long traverse is slow and the target floor is not visible until it scrolls in. If it proves tedious in playtest, easing the camera to fit-all on pickup is the contained alternative — the drag payload and drop-target logic are unaffected either way.

Match hints are not re-derived: the layout model calls the existing `Sim.match_hint()` and surfaces its answer as per-bay render state. ADR-0001 and ADR-0009 are otherwise untouched — tap-then-tap and drag coexist, and there is still no auto-matcher.

**Blocked by:** 08, 10

**Status:** ready-for-agent

- [ ] Dragging a guest onto a bay seats the Party there
- [ ] Tapping a guest then tapping a bay seats the Party there
- [ ] Both gestures show the same Needs bubble and the same bay glows
- [ ] Green, amber and no-glow bays match what `Sim.match_hint()` returns, with no hint logic duplicated in the view
- [ ] Seating an amber match still routes through the existing seat-confirm modal
- [ ] Holding a drag near the top or bottom edge pans the camera, and a lobby-to-top-floor drag is completable at full zoom
- [ ] Per-bay Match hint state is covered by tests against the pure layout model
