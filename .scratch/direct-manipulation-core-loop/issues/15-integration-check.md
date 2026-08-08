# 15 — Full headless multi-day integration check

**What to build:** A multi-day headless batch run exercising Floors, manual seating, Stations, and the full Dining loop together, proving the reworked systems cooperate over many days unattended — the same kind of run the project's balancing workflow depends on.

**Blocked by:** 02, 04, 06, 07, 09, 10, 11, 12

**Status:** ready-for-agent

- [ ] A 60-day headless batch run completes with no Party or dining guest stuck in an unresolvable state
- [ ] The run's output reflects Floors, Station assignments, and Dining activity (not just legacy room/guest metrics)
- [ ] Reputation/Hearts deltas from Dining outcomes appear in the run's output alongside Checkout-driven deltas
- [ ] The run completes using only the shared seat action and scripted autopilot rule from ticket 06 — no second admission or dining-resolution path introduced for the batch context
