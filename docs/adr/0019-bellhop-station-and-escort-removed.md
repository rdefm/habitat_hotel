# The Bellhop Station and the Escort Job are removed

Status: accepted, supersedes ADR-0014 (Bellhop-escorted check-in) and ADR-0017 (its implementation). ADR-0005 is unaffected as a decision -- Stations still beat Roles, and any Staffer still works any Station -- but its prose lists four posts including Bellhop, which is now stale.

ADR-0014 made check-in an **Escort** — a staffed Bellhop walks a just-seated Party to its Room over a Skill-scaled delay — and ADR-0017 implemented it as a parallel per-Staffer Job mirroring Housekeeping's, with a queue for Parties seated while every Bellhop is busy. Both shipped. `.scratch/visual-hotel-world/` then rebuilds the play surface as a drawn Node2D world, and drawing the Escort means building a second travelling-actor system — a Bellhop sprite pathing to the elevator, riding it with the guest, walking back — on top of the guest's own journey to the same Room.

That work isn't worth doing, because the mechanic underneath it doesn't earn its place. Bellhop is the one Station whose Job the player never decides anything about: Reception trades against Patience decay, Housekeeping against room turnaround, Kitchen against Dining service, but a Bellhop only ever makes an unavoidable delay shorter. There's nothing to weigh, so a Staffer parked there is a Staffer withheld from the three Stations that do pose a choice. With four Stations and three Staffers, that was also the *only* way to be under-covered, which made "leave Bellhop empty" the obviously correct opening move rather than a decision.

## Decision

**Bellhop stops existing.** Not deprecated, not left unstaffed by default — removed from `Station.IDS`/`LABELS`, from `GameState.DEFAULT_STATION_ASSIGNMENTS`, from every Staffer's Skill block in `data/staffers.json`, and from `data/balance.json`'s `stations` section. No Staffer can be assigned to it anywhere, because there is no "it" to assign to. The hotel runs on **Reception, Housekeeping and Kitchen**.

**The Escort Job goes with it.** `SimController` loses `_escort_jobs`, `_tick_escorts()`, `escort_job()`, `escort_staffers()`, the claim/queue/fallback helpers, and the `escort_mode` flag on a Room instance. `tests/test_bellhop_escort.gd` is deleted.

**Check-in keeps its delay.** A seated Party still doesn't land in its Room instantly — it walks there over the flat delay that was previously the *unstaffed* fallback, now the only path and the same 16 ticks it always was, moved from `stations.bellhop.unstaffed_checkin_delay_ticks` to a top-level `checkin.delay_ticks` since it's no longer any Station's tuning. `_start_checkin()` has one branch instead of two.

**Marlon starts unassigned.** He was Bellhop's default Staffer; rather than move him onto another Station and silently change that Station's starting service level, he starts in the Staff Pool — a state `staffer_station()` has always returned `""` for and `ui/station_panel.gd` already renders its own row for. Three Staffers over three Stations means full coverage is now reachable, and choosing to leave one empty is a real trade rather than a forced one.

This is deliberately a Sim-layer change made *before* the world rebuild, not during it, so the drawn hotel never learns a Station and a Job that are on their way out. It, and the `max_instances` cut, are the two places `.scratch/visual-hotel-world/spec.md` crosses the presentation-only boundary ADR-0016 drew.

## Considered Options

- **Keep Bellhop, draw the Escort (rejected)** — honours ADR-0014/0017, but builds a second travelling-actor system for a mechanic with no decision in it, and the whole build is thrown away the moment the mechanic is cut anyway.
- **Keep Bellhop as a Station, drop only the Escort Job (rejected)** — leaves a Station whose entire effect is a flat delay nobody can influence: strictly worse than removing it, since it still absorbs a Staffer and still needs a drawn post.
- **Give Bellhop a real decision instead (rejected, for now)** — e.g. luggage handling that feeds satisfaction. A new mechanic, not a rescue of this one; nothing stops a future ADR from adding a fourth Station once it has a trade-off worth making.
- **Remove Bellhop outright (chosen)** — smallest surface, and the only option that leaves the Station roster all-choices.

## Out of Scope

- Reception, Housekeeping and Kitchen behaviour — untouched, including Reception's unstaffed Patience multiplier and the Stacking cap (ADR-0008), which only ever applied to Housekeeping/Kitchen Jobs anyway.
- Rebalancing anything for three Stations. The check-in delay keeps its exact tick count; no other tuning moves.
- `GUIDE.md`'s §13/§15 Bellhop mentions — that document already describes a hire/fire pool ADR-0002 rejected and a Policy menu ADR-0001 removed, so it needs its own pass rather than a Bellhop-shaped patch.
