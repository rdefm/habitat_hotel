# 11 — The elevator and the guest journey: check-in, occupancy, checkout, turn-away

**What to build:** The building gets its circulation spine, and the player gets to watch the outcome of the decision they just made.

A seated guest walks to the elevator, rides the car up, and walks into their Room. They stay visible inside it for the whole stay, in fixed spots in their bay, so an occupied Room reads as occupied from across the building — and they sleep with a Zz at Night. A checking-out guest is the visible mirror: out of the Room, down the car, out of the lobby. A turned-away Party walks back out of the lobby, so a lost booking is as legible as a won one.

The elevator is functional but presentation-only. All timing continues to come from the existing durations in `SimController`; the car introduces no capacity limit, no queueing rule and no new Sim state. An actor whose Sim-side travel completes while the car is mid-flight is placed at its destination regardless — the animation never gates the simulation.

Actor animation states are idle, walk, and one context state — sleeping for a Guest at Night. There is no wander behaviour and no ambient behaviour scheduler.

**Blocked by:** 11

**Status:** ready-for-agent

- [ ] A seated guest walks to the elevator, rides it, and walks into their Room
- [ ] Guests stay visible in their Room for the whole stay, at fixed spots in the bay
- [ ] Guests show a sleeping state with a Zz at Night
- [ ] A checking-out guest leaves the Room, rides down and walks out
- [ ] A turned-away Party walks out of the lobby
- [ ] Sim timing is unchanged: an actor whose travel resolves mid-animation is placed at its destination and the simulation never waits on a tween
- [ ] Room occupancy placement is covered by tests against the pure layout model
