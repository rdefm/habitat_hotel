# 11 — The elevator and the guest journey: check-in, occupancy, checkout, turn-away

**What to build:** The building gets its circulation spine, and the player gets to watch the outcome of the decision they just made.

A seated guest walks to the elevator, rides the car up, and walks into their Room. They stay visible inside it for the whole stay, in fixed spots in their bay, so an occupied Room reads as occupied from across the building — and they sleep with a Zz at Night. A checking-out guest is the visible mirror: out of the Room, down the car, out of the lobby. A turned-away Party walks back out of the lobby, so a lost booking is as legible as a won one.

The elevator is functional but presentation-only. All timing continues to come from the existing durations in `SimController`; the car introduces no capacity limit, no queueing rule and no new Sim state. An actor whose Sim-side travel completes while the car is mid-flight is placed at its destination regardless — the animation never gates the simulation.

Actor animation states are idle, walk, and one context state — sleeping for a Guest at Night. There is no wander behaviour and no ambient behaviour scheduler.

**Blocked by:** 11

**Status:** done

- [x] A seated guest walks to the elevator, rides it, and walks into their Room
- [x] Guests stay visible in their Room for the whole stay, at fixed spots in the bay
- [x] Guests show a sleeping state with a Zz at Night
- [x] A checking-out guest leaves the Room, rides down and walks out
- [x] A turned-away Party walks out of the lobby
- [x] Sim timing is unchanged: an actor whose travel resolves mid-animation is placed at its destination and the simulation never waits on a tween
- [x] Room occupancy placement is covered by tests against the pure layout model

## Comments

Implemented in `sim/building_layout.gd`: `room_occupant_placements(party_size)`/`room_occupant_point_local()` give a built Room's occupant(s) fixed spots in a small 2-column grid within their own bay, capped at `ROOM_OCCUPANT_MAX_VISIBLE` (4) so an upgraded Room's higher capacity never visually overflows the ~166px bay -- cosmetic-only, the same "not authoritative" trade-off the mess overlay/upgrade props already make. `resolve_room_occupant_point()` combines that grid with `room_bay_rect_local()` through the same floor-top-edge translation every other indexed anchor in the file uses. `floor_index_for_room_type()` is the new lookup the elevator journey needs to find a Room floor's own `elevator_door` anchor. `tests/test_room_occupant_placement.gd` (9 tests) covers all three, same shape as `tests/test_lobby_guest_placement.gd`.

`ui/room_occupant_actor.gd` (new) wraps a `CharacterSprite` for one settled occupant, idle by day and "sleeping" at Night with a small "Zz" `Label` standing in for a sleeping animation no asset carries yet.

`ui/hotel_world.gd`'s new "Elevator journeys" section is the presentation-only piece: on `EventBus.guest_seated` a fresh actor idles at the front desk (`idle` state) for as long as `room["checking_in"]` stays true -- polled every frame against Sim's own flat `checkin.delay_ticks` countdown, never re-timed -- then switches to `walk` and plays three sequential real-time tweens (front desk → that floor's `elevator_door`, `elevator_door` → the Room floor's own `elevator_door` with a small translucent car decoration parented to the actor for that leg only, then `elevator_door` → the Room's first occupant spot). `EventBus.guest_checked_out` (emitted by Sim *before* it clears the Room's occupant fields) plays the exact reverse trip with no waiting leg, ending outside the building; `EventBus.guest_turned_away` walks every member of the lost Party's own still-live lobby actors out the same exit point, no elevator involved. Both directions share one `_play_ride_legs()` tween-builder and one `_new_journey()` record constructor.

A Room's settled occupant only ever renders once `_rebuild_room_occupants()` sees neither `room["checking_in"]` nor an entry in `_active_room_journeys` for that Room -- the journey owns the visible guest for the whole trip there and back, so the static render and the in-flight journey never show the same guest twice. `_rooms_signature()` folds `Clock.current_phase` into the existing `hotel_rooms`-based rebuild signature so a bare Night transition (no `hotel_rooms` mutation) still swaps every settled occupant to `sleeping`. Every leg duration is a fixed real-time constant (the ride leg scales a little with floor distance, clamped) -- none of it derives from Sim's own tick counts, and nothing in this file ever awaits a tween before letting Sim continue, so the animation can't gate the simulation.

Verified end-to-end with a throwaway GUT test driving `Sim.seat_party()`/`Clock.force_advance_ticks()` directly against a live `HotelWorld` in a real SceneTree (GUT provides one even headless): the check-in journey correctly waits, rides, arrives, and hands off to the static occupant render; the checkout journey correctly starts on `_do_morning()`'s checkout and self-cleans. Also ran the full game headlessly for a real Day 1 with no manual seating, confirming five automatic turn-aways each played their walk-out with no errors. That scratch test was not committed (spec.md's Testing Decisions keep elevator movement/tween timing playtest-verified, not unit-tested).

Full suite: 247 tests, 235 passing, 12 pre-existing failures -- same set prior tickets' runs already confirmed unrelated (batch-runner-autopilot, checkout-review, day-night-cycle, integration-multiday, manual-seating, room-guest-dinner-addon).
