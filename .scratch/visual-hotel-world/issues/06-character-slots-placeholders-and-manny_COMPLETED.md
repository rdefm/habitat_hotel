# 06 — Character slots, placeholders, and Manny

**What to build:** The character side of the asset contract, proven by the one real character the project has.

The contract gains its character and interface slots: per-Species guest sprites, per-Staffer sprites, the eight Tag icons, mood faces, Station post props, and HUD pills — each with its dimensions, anchor, frame count and animation states. Animation states are idle, walk, and one context state — sleeping for a Guest, working for a Staffer. There is no wander behaviour and no ambient behaviour scheduler.

Every one of these slots is empty today, so all of them exercise ticket 05's fallback rule: a placeholder of identical footprint, tinted per species or Staffer, carrying a short label such as a species abbreviation. The label is deliberately temporary so the Match puzzle is playtestable before art exists, and it disappears when its slot's asset lands. Getting the footprints right here is what makes every later ticket's layout trustworthy before any art is drawn.

Manny is the reference implementation: his existing walk and sweep sprites load through the contract like any other character, at a real size, with real animation states, standing somewhere in the world and moving. He is the proof the pipeline works end to end.

`character_idle.png`/`.webp` and the two UUID-named PNGs in `assets/` are unused leftovers and get no slot. ADR-0015's constraint — that the animation system accept a new sprite set per Staffer/task without redesign — is honoured here and closed.

**Blocked by:** 02, 05

**Status:** done

- [x] The contract covers per-Species guests, per-Staffer sprites, Tag icons, mood faces, Station props and HUD pills, with idle/walk/context states named per slot
- [x] Every character slot with no asset renders a labelled, correctly-sized placeholder, and the game stays playable
- [x] Manny renders through the contract with his walk and sweep animations at his contract footprint
- [x] Dropping a correctly-named, correctly-sized character file into a slot replaces its placeholder with no code change
- [x] Character slot resolution and fallback are covered by tests against the pure layout model
- [x] The unused leftover assets are removed or left unreferenced, with no slot pointing at them
- [x] ADR-0015 is marked closed

## Comments

Implemented in `sim/building_layout.gd` (extended again, same as ticket 05): `resolve_character_sprite()` (per-Species/per-Staffer sprites, alias-then-convention-then-placeholder same shape as `resolve_room_interior()`) plus four single-frame siblings — `resolve_tag_icon()`, `resolve_mood_face()`, `resolve_station_prop()`, `resolve_hud_pill()`. `placeholder_tint_for_id()`/`placeholder_label_for_id()` are shared helpers: a deterministic hash-derived hue (spread across a million buckets, not 360, after an empirical collision on the 8-Species roster at 360) and a 3-letter uppercase abbreviation. 24 new tests in `tests/test_character_contract.gd`.

Character sheets convention: `assets/characters/<kind>s/<id>_<state>.png`, cut to a fixed 64×64 per frame — chosen to match the concept art already dropped under `assets/` (pigeon/penguin/tortoise, all 64×64) and the sprite-generation tool's own `frame_w`/`frame_h`. Manny is the one alias, not a convention fit: his existing 256×256-per-frame `Manny-walk.png`/`Manny-sweeping.png` sheets are fixed in `CHARACTER_SPRITE_FILE`, scaled to the same 64×64 footprint at render time. He has no `idle` sheet, so that state falls through to the placeholder like anyone else's would — proving the alias and the fallback share one resolver.

`ui/character_sprite.gd` is the new generic renderer: a real `AnimatedSprite2D` sliced into frames off the loaded texture's own pixel size (never assumed), or the tinted/labelled placeholder — same file-existence-check-free split as the building shell. `ui/hotel_world.gd` stands Manny at Reception's staff nook playing his walk animation. Deliberately **not** patrolling between the nook and the front desk — an earlier draft did, and code review caught it as unrequested ambient/wander behaviour (spec.md's Out of Scope rules this out) that also misused `front_desk`'s "assigned Staffer's post" meaning for a Staffer who's actually unassigned. "Standing somewhere in the world and moving" is his animated walk-cycle playing in place; his `working` (sweep) alias was verified rendering through the identical path via a manual screenshot swap, not shipped live, since nothing yet drives which state should show (no real Job exists until tickets 07/08).

Guest sprites, Tag icons, mood faces, Station props and HUD pills are resolver-and-test-only in this ticket, not spawned live in the running world — their consumers (lobby guests, the Needs bubble, Station posts, the HUD strip) are tickets 07/10/14, and spec.md's Testing Decisions section names the pure layout model as "the only new test target," with rendering staying playtest-verified. Confirmed via `--screenshot=` (both the real Manny sprite and, in a temporary throwaway check, a placeholder-rendered Staffer) that both `CharacterSprite` paths draw correctly at their contract footprint.

`character_idle.png`/`.webp` and the two UUID-named PNGs are removed outright (no code ever referenced them). `assets/tortoise.png`/`tortoise_idle_1.zip`/`tortoise_walks.zip` — a concurrent art-pipeline drop appearing mid-session, same as ticket 05's pigeon/penguin note — are committed separately, unreferenced, carrying no slot.

ADR-0015's status line is rewritten to `closed`: ADR-0018 had already claimed to close it, but only ever wired Manny's animation into the Control-tree view (`ui/station_panel.gd` and friends) that ADR-0020 subsequently replaced wholesale — so the constraint (a new sprite set drops in per Staffer/task with no redesign) is re-earned here against the real, generic resolver rather than inherited from a claim against deleted code.

Full suite: 178 tests, 165 passing, 13 pre-existing failures — same set ticket 05's A/B run already confirmed unrelated.
