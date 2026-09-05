# 06 — Character slots, placeholders, and Manny

**What to build:** The character side of the asset contract, proven by the one real character the project has.

The contract gains its character and interface slots: per-Species guest sprites, per-Staffer sprites, the eight Tag icons, mood faces, Station post props, and HUD pills — each with its dimensions, anchor, frame count and animation states. Animation states are idle, walk, and one context state — sleeping for a Guest, working for a Staffer. There is no wander behaviour and no ambient behaviour scheduler.

Every one of these slots is empty today, so all of them exercise ticket 05's fallback rule: a placeholder of identical footprint, tinted per species or Staffer, carrying a short label such as a species abbreviation. The label is deliberately temporary so the Match puzzle is playtestable before art exists, and it disappears when its slot's asset lands. Getting the footprints right here is what makes every later ticket's layout trustworthy before any art is drawn.

Manny is the reference implementation: his existing walk and sweep sprites load through the contract like any other character, at a real size, with real animation states, standing somewhere in the world and moving. He is the proof the pipeline works end to end.

`character_idle.png`/`.webp` and the two UUID-named PNGs in `assets/` are unused leftovers and get no slot. ADR-0015's constraint — that the animation system accept a new sprite set per Staffer/task without redesign — is honoured here and closed.

**Blocked by:** 02, 05

**Status:** ready-for-agent

- [ ] The contract covers per-Species guests, per-Staffer sprites, Tag icons, mood faces, Station props and HUD pills, with idle/walk/context states named per slot
- [ ] Every character slot with no asset renders a labelled, correctly-sized placeholder, and the game stays playable
- [ ] Manny renders through the contract with his walk and sweep animations at his contract footprint
- [ ] Dropping a correctly-named, correctly-sized character file into a slot replaces its placeholder with no code change
- [ ] Character slot resolution and fallback are covered by tests against the pure layout model
- [ ] The unused leftover assets are removed or left unreferenced, with no slot pointing at them
- [ ] ADR-0015 is marked closed
