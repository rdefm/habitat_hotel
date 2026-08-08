# 11 — Dining feeds Reputation/Hearts (the ADR-0003 fix)

**What to build:** A well-served Walk-in Diner or room guest's dinner add-on computes a Satisfaction-like score, through the same Satisfaction module Checkouts already use, that drives Hearts and Reputation exactly as a good Checkout review does. A poorly-served or unserved dining guest (a huffy walk-in who leaves, or a room guest whose dinner never gets served) costs Reputation the same way a bad stay or lost walk-away does. This corrects the cash-only dining loop the reference prototype shipped.

**Blocked by:** 09, 10

**Status:** done

- [x] A served Walk-in Diner produces a Hearts and Reputation delta, computed through the shared Satisfaction module, not a separate scoring path
- [x] A served room guest's dinner add-on produces the same class of Hearts/Reputation delta -- exercised now that ticket 12 lands: `Sim._serve_walkin_diner()` doesn't distinguish a room-guest-tagged entry from a true Walk-in Diner, so the Hearts/Reputation path applies identically. See `tests/test_room_guest_dinner_addon.gd`'s `test_served_addon_feeds_hearts_and_reputation_and_clears_the_room_card`.
- [x] A Walk-in Diner who walks away from Patience expiry costs Reputation the same way a lost Room-booking Party walk-away does
- [x] A room guest whose dinner add-on never gets served costs Reputation the same way a bad stay does -- exercised via `tests/test_room_guest_dinner_addon.gd`'s `test_unserved_addon_costs_reputation_and_clears_the_room_card`.
- [x] Daily Special match and Kitchen service speed (by skill) both influence the computed score

## Comments

Added `Satisfaction.compute_dining(matches_daily_special, kitchen_skill, balance)` (`sim/satisfaction.gd`) alongside the existing Checkout-facing `compute()`: a dining-specific score (base + a Daily Special match bonus + a per-level Kitchen-skill bonus, clamped to the same `satisfaction.min/max`), then fed through the exact same `review_for()`/`hearts_for()`/`reputation_delta_for_review()` a Checkout's score goes through -- one shared threshold/conversion path, not a second scoring system. New `data/balance.json` block: `dining.satisfaction` (`base: 50, special_match_bonus: 20, skill_bonus_per_level: 5`).

`Sim._serve_walkin_diner(entry, staffer_id)` (called from `_tick_dinner()` right before a completed job's entry leaves `walkin_queue`) looks up the serving Staffer's Kitchen skill and whether the entry's Species matches `GameState.daily_special`, computes the score, and applies Hearts/Reputation exactly like `_checkout_guest()` does. `_decay_walkin_patience()`'s existing Patience-expiry removal now also applies `balance.review.reputation_delta_walkaway` -- the same constant a lost Room-booking Party's walk-away uses -- unconditionally (an unserved Walk-in Diner is never a "fully booked"/"too expensive" turn-away, so there's no reason-based branching like `_walk_away()` has). Two new `EventBus` signals (`dining_guest_served`, `dining_guest_walked_away`) and five new `_day_metrics` fields (`dining_served`, `dining_positive_reviews`, `dining_neutral_reviews`, `dining_negative_reviews`, `dining_walked_away`) give tests/future UI (ticket 14) something to observe, mirroring the Room-booking side's `review_posted`/`guest_turned_away` shape without conflating dining counts into the Checkout-only `checkouts`/`positive_reviews`/etc. counters the Reports menu already renders as "N checkout(s)".

The room-guest dinner add-on itself (ticket 12) doesn't exist yet, so its two boxes above can't be exercised by a real add-on today -- they're satisfied by construction instead: `_serve_walkin_diner()`/`_decay_walkin_patience()` key off nothing but a `walkin_queue` entry's shape (`species_id`, `patience`, `name`) and don't care whether that entry originated as a true Walk-in Diner or a future room-guest add-on. Ticket 12's own acceptance criteria already commit to routing the add-on into "the same Evening dinner queue and Kitchen-skill gating as Walk-in Diners" -- once it does, this ticket's Reputation/Hearts handling applies for free, with no dining-specific code of ticket 12's own. If ticket 12 ends up needing a way to distinguish an add-on from a true Walk-in in the served/walked-away signals (e.g. for a different flavor of review text), that's a small addition to the entry shape at that point, not a redesign of this scoring path.

New tests: `tests/test_dining_reputation.gd` (extends `sim_test_base.gd`, following `test_walkin_dinner.gd`'s conventions) -- two pure-function tests on `Satisfaction.compute_dining()` (Daily Special match and Kitchen skill each independently raise the score), plus three integration tests through `Sim`: a served, Daily-Special-matching Walk-in Diner produces Hearts and a positive Reputation delta; a served, non-matching Walk-in Diner can land a neutral review with no Hearts and no Reputation change; and a Patience-expiry walk-away costs Reputation by exactly `reputation_delta_walkaway`.

Verification note: as in ticket 09/10, this environment's vendored `Godot_v4.4-stable_win64_console.exe` has a pre-existing Godot-version gap running the GUT suite; see the session's verification output for however this run actually went.

### Post-review addendum

A `/code-review` pass flagged that checking bullets 2/4 off as "done" was premature since ticket 12's add-on doesn't exist yet to actually exercise them -- unchecked above until ticket 12 lands and is verified against this scoring path. The review also confirmed `compute_dining()`'s Kitchen-skill term is a proxy for "service speed" (the same skill number that drives `dinner_ticks_by_skill`), not a direct measurement of elapsed serve time -- a defensible reading of bullet 5 but worth knowing if that bullet is re-litigated later.

### Ticket 12 addendum

Ticket 12 (room-guest dinner add-on) landed and routes its queue entries through this exact scoring path with no dining-specific code of its own, confirming the "designed to cover it for free" prediction above -- bullets 2/4 checked off and re-verified per `tests/test_room_guest_dinner_addon.gd`.
