# 09 — Guests in the lobby: mood faces and Needs bubbles

**What to build:** Arriving Parties stand in the lobby as individual animal characters — a Party of three is three characters standing together, so party size is seen rather than read, and each is drawn from its Species' sprite slot (a placeholder until that art lands).

A mood face floats above every waiting guest at all times, souring continuously as Patience decays through content, impatient and huffy, so someone about to walk out is spottable from across the whole hotel rather than at a threshold crossing.

Tapping a waiting guest pops a bubble of Tag icons showing their Needs — the Match puzzle solved against icons, not a text card. Waiting diners on the Terrace use the same mood faces, so dining Patience reads the same way everywhere.

The layout model gains the lobby queue placement bucket and the mapping from a Patience value to a mood-face state.

**Blocked by:** 07, 09

**Status:** done

- [x] An arriving Party stands in the lobby as one character per member, drawn from its Species slot
- [x] Every waiting guest carries a mood face at all times, with no tap required
- [x] The mood face sours continuously as Patience decays, through content, impatient and huffy
- [x] Tapping a waiting guest pops a bubble of Tag icons for its Needs
- [x] Waiting diners at the Terrace show the same mood faces as lobby guests
- [x] Patience-to-mood mapping and lobby placement are covered by tests against the pure layout model

## Comments

Implemented in `sim/building_layout.gd`: `lobby_guest_placements(pending_arrivals)` flattens `Sim.pending_arrivals` into one `{party_id, member_index, queue_index}` entry per Party MEMBER (not per Party), so a Party of three occupies three consecutive `lobby_queue` slots and party size is seen rather than read. `resolve_lobby_guest_point()` resolves a `queue_index` straight through the existing `lobby_queue` anchor (ticket 05). `resolve_mood_face_for_patience(patience, patience_cfg)` is the new Patience-value-to-mood-face seam: it classifies the raw value via `sim/patience_state.gd`'s `PatienceState.tier()` before resolving the tier through the existing `resolve_mood_face()`, so the same resolver serves a lobby Party (`GameState.balance["patience"]`) and a Terrace diner (`GameState.balance["dining"]["walkin_patience"]`) against their own different thresholds.

`ui/guest_actor.gd` (new) renders one lobby guest per member -- a `CharacterSprite` at the `guest` kind's `idle` state plus an always-visible mood-face `CharacterSprite` floating above it, mirroring `ui/diner_actor.gd`'s shape. `ui/diner_actor.gd` gained the identical mood-face treatment so Terrace diners sour the same way lobby guests do. `ui/needs_bubble.gd` (new) draws a tap-popped stack of Tag icon slots (`resolve_tag_icon()`) for a Party's own `needs` array -- a Walk-in Diner has no `needs` array, so diners carry a mood face but are never a tap target.

`ui/hotel_world.gd` rebuilds every lobby guest actor whenever `Sim.pending_arrivals` changes (a new `_lobby_signature()` poll, same shape as ticket 09's dining signature) -- since Patience decays every tick, this is effectively every tick, which is what keeps every mood face current with no separate update path. Tapping a guest (the same press/release-with-a-movement-threshold hit-testing every other tap target in this file uses) opens/closes a Needs bubble via `_toggle_needs_bubble()`; a rebuild that drops the bubble's guest closes it, one that merely shifts its queue position re-anchors it. Tapping anywhere that isn't the bubble's own guest -- a Staffer, a Room bay, the Terrace signage, or empty space starting a camera pan -- closes it too.

11 new tests: 6 in `tests/test_lobby_guest_placement.gd` (member-flattening, queue continuation across Parties, point resolution) plus 5 in `tests/test_character_contract.gd` (`resolve_mood_face_for_patience()` against both the Reception and dining Patience configs, including a value that sours through all three tiers).

Full suite: 233 tests, 220 passing, 13 pre-existing failures -- confirmed via a stash/baseline comparison to be identical to the failures already present before this ticket's changes (unrelated: checkout/review, day-night-cycle, hotel-background-slices, integration-multiday, manual-seating, room-guest-dinner-addon).
