# 06 — Batch runner autopilot rework

**What to build:** The headless batch runner keeps driving day-by-day simulation unchanged, but its arrival handling now seats every pending Party through the same seat action interactive play uses, choosing a Room via a simple scripted rule: prefer the smallest-capacity green match, else the smallest-capacity amber match, else leave the Party to expire. The runner's policy argument is removed.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] The batch runner seats arrivals only through the shared seat action — no second admission implementation
- [ ] Given a green match is available, the runner picks the smallest-capacity green Room over any amber Room
- [ ] Given no green match but an amber match is available, the runner picks the smallest-capacity amber Room
- [ ] Given neither is available, the Party is left in the queue to expire on its own Patience
- [ ] The runner's policy parameter is gone from its public entry point
