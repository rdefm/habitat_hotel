# 04 — Room floor reskin: walk-in animation and persistent occupancy

**What to build:** On a successful seat (drag or tap flow), the guest actor visibly walks from the Reception floor up through the building to the actual Room cell it was dropped/assigned onto — replacing today's abstracted "elevator" fade-out stand-in with a real point-to-point move to a real target. If the seat goes through a Bellhop Escort, the Bellhop's own actor visibly travels alongside the guest for the Escort's duration before the walk-in plays; an unstaffed/flat-delay seat plays the walk-in after that delay with no accompanying Bellhop actor. Once arrived, the guest actor does not despawn — it stays parented at the Room cell as that Room's occupant actor for the whole stay (static/idle placeholder, no fancy animation yet), alongside the Room cell's existing occupied-state info display.

**Blocked by:** 02, 03, 01

**Status:** ready-for-agent

- [ ] A successfully-seated guest's actor animates from the Reception floor to the specific Room cell it was seated in, ending at that cell's real position
- [ ] When the seat went through a staffed Bellhop Escort, the Bellhop's actor visibly travels with the guest for the Escort's duration before the Room occupies
- [ ] When the seat went through the unstaffed flat delay, the walk-in animation plays after that delay with no Bellhop actor accompanying it
- [ ] The guest actor remains visibly standing in the Room cell for the duration of the stay (until checkout), not despawning after the walk-in animation
- [ ] The Room cell's existing occupied-state info (guest name, species, fit, dinner add-on) still displays alongside the persistent occupant actor, unchanged from today
- [ ] A Party split across multiple Rooms (oversized Party) produces one walk-in animation and one persistent occupant actor per Room chunk, matching the existing per-chunk admission behavior
