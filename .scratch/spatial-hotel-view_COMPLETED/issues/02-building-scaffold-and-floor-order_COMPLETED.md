# 02 — Building cross-section scaffold and floor-order fix

**What to build:** The structural skeleton of the new spatial view: a single vertically-scrolling container mounted below the stats strip, with a fixed Reception floor at the bottom, a fixed Terrace floor directly above it, and one Floor per unlocked Room type stacked above that in ascending unlock-star order — replacing today's alphabetical Room-type sort. Each Room floor keeps today's per-type row of built-instance cells plus a trailing Build Slot cell under its instance cap, with the same drop-target/tap semantics as today. This ticket is about the container and ordering, not yet the actor reskin — cells can stay visually as today's buttons for now; later tickets layer the actor reskin on top. Floor height stays fixed as the stack grows; the container scrolls vertically rather than compressing.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Reception, Terrace, and every unlocked Room type each render as a distinct floor in one vertically-stacked, vertically-scrolling container
- [ ] Room-type floors are ordered bottom-to-top by ascending unlock star, verified against a case where the current alphabetical sort would produce a different order
- [ ] A newly-unlocked Room type's floor appears in the correct position by star order, not appended alphabetically
- [ ] Every Room floor's Build Slot / built-instance-cell behavior (tap-to-build, tap-to-upgrade, Party-seat drop target, Staffer-stack drop target) is unaffected by the container rework
- [ ] Floor height does not shrink as more floors are added; the container scrolls instead
- [ ] The stats strip at the very top is unaffected by any of this
