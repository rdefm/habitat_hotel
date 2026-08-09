# Multiple Staffers can Stack on one Housekeeping/Kitchen Job

The shipped Station model runs Housekeeping/Kitchen work one Staffer per Job in parallel — assigning a second Staffer means a second Job starts on a different target, never the same Job finishing faster. We're adding **Stacking**: up to 2 Staffers can share a single Job (a Room-clean or a Diner/breakfast entry's meal service), summing their Skill (capped at the existing scale's max level, 5) and looking up the combined service time in the same per-skill tick tables already in `balance.json` — no new formula, just a documented sum-then-cap-then-lookup rule. Reception and Bellhop don't get Stacking; they have no per-target Job to share.

We considered vision-chunk-2's rush-clean model instead (pull a Staffer to rush a *different* dirty Room in parallel, strictly one worker per Room, see ADR-0006) and rejected it: it doesn't deliver "drop two people on one Room to finish it faster," which is the point of this feature.

Status: accepted.
