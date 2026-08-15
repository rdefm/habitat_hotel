# 05 — Checkout and turn-away animations

**What to build:** The symmetric reverse of ticket 04's walk-in. On checkout, a Room's persistent occupant actor animates back down through the building from its Room cell to Reception and despawns there, mirroring today's checkout round-trip but now starting from the guest's real Room. On turn-away (a pending arrival that walks away — no eligible Room, fully booked, or too expensive), the arriving guest's actor animates from the Reception queue back out the entrance and despawns, mirroring today's turn-away animation but from the real Reception queue position.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] A Room's occupant actor animates from that Room's real cell position back down to Reception and despawns on checkout
- [ ] A pending arrival that walks away (any of the three existing reasons: no eligible Room, fully booked, too expensive) animates from its real position in the Reception queue back out and despawns
- [ ] Both animations play regardless of which Room/queue-position the guest actor was actually at, not a fixed stand-in position
- [ ] No leaked actor nodes after either animation completes (verified by manual play across multiple check-ins/checkouts/turn-aways in one session)
