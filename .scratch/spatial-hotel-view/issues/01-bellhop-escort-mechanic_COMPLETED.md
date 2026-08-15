# 01 — Bellhop Escort mechanic (Sim layer)

**What to build:** Implement ADR-0014/ADR-0017 for real. Today a staffed Bellhop seats a Party instantly and only the unstaffed case gets a delay; flip the staffed case to a Skill-scaled Escort delay via a per-Bellhop-Staffer Job model mirroring Housekeeping's parallel per-Staffer cleaning jobs. Each assigned, currently-idle Bellhop Staffer claims the next Party awaiting Escort and works it down over a new Skill-scaled tick table. Multiple assigned Bellhops escort different Parties in parallel. A Party seated while every assigned Bellhop is already mid-Escort joins a waiting-for-Bellhop queue and is picked up by the next Bellhop that frees up — it does not fall back to the unstaffed flat delay. The unstaffed case's existing flat delay is unchanged. This is a pure Sim-layer addition; no UI dependency.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] A new Skill-scaled tick table exists in the Bellhop balance data (shaped like Housekeeping's clean-ticks-by-skill table), and a staffed Bellhop's Escort takes measurably longer at Skill 1 than at Skill 5
- [ ] Two Staffers assigned to Bellhop can each be mid-Escort on a different Party at the same time
- [ ] A Party seated while every assigned Bellhop is already mid-Escort is held in a waiting-for-Bellhop state (not seated, not walked away) rather than falling back to the flat unstaffed delay
- [ ] A waiting Party is picked up automatically once any assigned Bellhop frees up
- [ ] Reassigning a mid-Escort Bellhop Staffer off the Bellhop Station interrupts only that Staffer's own Escort (the Party returns to waiting-for-Bellhop, or falls back to unstaffed behavior if no Bellhop remains assigned) without affecting any other Staffer's in-flight Escort, mirroring Housekeeping's existing interrupt semantics
- [ ] The unstaffed Bellhop case (flat delay, no Escort) is unchanged from today's behavior, byte-for-byte
- [ ] A full multi-day headless batch run completes with no Party stuck in an unresolvable Escort-wait state
- [ ] Headless tests cover all of the above against the Sim's public API, following the existing Roster/Station and Stacking test conventions
