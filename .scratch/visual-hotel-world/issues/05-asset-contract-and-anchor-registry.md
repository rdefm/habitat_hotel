# 05 — The asset contract and the anchor registry

**What to build:** The document that says where everything in the building goes, and the code that resolves it — so art can be produced against a fixed target and dropped in without touching code.

The contract fixes, per slot: file path pattern, pixel dimensions, anchor point, frame count and animation states. This ticket covers the building side of it — the shell and elevator slices from ticket 03, per-Room-type floor and interior art, and the Reception and Terrace bands. It also states the fallback rule the whole contract obeys: a missing asset renders a placeholder occupying the identical footprint, tinted and labelled, and resolution lives in the layout model so the renderer never checks for a file. Ticket 06 applies that rule to characters.

Because the building is real art rather than a computed layout, the contract carries an **anchor registry**: the rects and points within each band where things stand — the two Room bays, the elevator door on each floor, the lobby queue line, the front desk, supply closet and staff nook positions, the Terrace's diner spots and its entrance queue. The layout model resolves an anchor plus a floor's position into a world position, and the renderer derives nothing of its own.

Three of the six Room types have painted interiors; the other three exercise the fallback and show a labelled placeholder band of identical footprint. That contrast is the ticket's own proof that the fallback works.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] The contract document fixes path, dimensions, anchor, frame count and animation states for every building-side slot, and states the placeholder fallback rule for all slots
- [ ] The anchor registry names every standing position in every band, and the layout model resolves each to a world position given the floor's placement
- [ ] The three painted Room types render real interiors; the other three render labelled placeholders of identical footprint
- [ ] A correctly-named, correctly-sized file dropped into a building slot replaces its placeholder with no code change
- [ ] Anchor resolution and building-slot resolution with fallback are covered by tests against the pure layout model
- [ ] The renderer contains no file-existence check
