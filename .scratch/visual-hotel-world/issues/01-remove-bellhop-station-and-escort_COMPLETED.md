# 01 — Remove the Bellhop Station and the Escort Job

**What to build:** The hotel runs on three Stations — Reception, Housekeeping, Kitchen. Bellhop is gone as a Station a Staffer can be assigned to, and the Escort is gone as a Job: a seated Party goes to its Room on the unstaffed check-in path that already exists for the no-Bellhop-free case, with no escorted variant. Nothing about Housekeeping, Kitchen or Reception changes. This is a deliberate Sim-layer excision done before the world rebuild starts, so the drawn hotel never learns about a Station and a Job that are on their way out; it supersedes the parent spec's "no Sim behaviour changes" clause alongside the `max_instances` cut in ticket 02.

The removal is total — the Station enum entry, the Escort Job and its claim/tick/resolve path in `SimController`, its balance tuning, its per-Staffer Skill entries, its test file, and its vocabulary in `CONTEXT.md`. ADR-0014 (Bellhop-escorted check-in) and ADR-0017 (its implementation) are superseded by a new ADR recording why the mechanic was cut. The old Control view keeps working throughout, minus its Bellhop card.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [x] No Staffer can be assigned to Bellhop anywhere in the game; the Station no longer exists in the Station vocabulary or in per-Staffer Skill data
- [x] A seated Party reaches its Room on the existing unstaffed path, at the existing flat delay, with no escorted branch remaining
- [x] Escort Job state, claiming, ticking and resolution are gone from `SimController`, with no dead branches left behind
- [x] Bellhop tuning is removed from `data/balance.json` and Bellhop Skill entries from `data/staffers.json`
- [x] `tests/test_bellhop_escort.gd` is deleted and every remaining test passes, including the Station-count and Stacking assertions that referenced Bellhop
- [x] `CONTEXT.md`'s **Escort** entry is removed and its **Station**, **Job** and **Stacking** entries no longer name Bellhop
- [x] A new ADR supersedes ADR-0014 and ADR-0017, and both are marked superseded
- [x] The old Control view still runs and is playable with three Stations
