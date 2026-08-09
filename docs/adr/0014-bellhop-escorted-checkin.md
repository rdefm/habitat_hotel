# Bellhop check-in becomes an escorted delay

Seating a Party (`Sim.seat_party()`) currently occupies the Room instantly regardless of Bellhop staffing; `balance.json`'s `stations.bellhop.unstaffed_checkin_delay_ticks` only ever penalizes the *no*-Bellhop case. We're making check-in an **Escort** whenever a Bellhop Staffer is free: they walk the Party up over a Skill-scaled delay (visibly animated per ADR-0015 when the Bellhop is Manny) before the Room occupies. With no Bellhop assigned, check-in still completes on its own, just without the Escort — the existing graceful-degradation behavior is unchanged.

Status: accepted.
