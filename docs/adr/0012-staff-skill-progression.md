# Staff Skill progression via passive XP and free Training

Staffer Skills have shipped fixed forever at their `data/staffers.json` values. We're making them progress: a Staffer earns XP in whichever Skill they're actively working, and can instead be put into a **Training** state — off Station entirely, gaining that one chosen Skill's XP faster — as a free action (no cash/Hearts cost; the only cost is being off the floor while training). Skill is soft-capped at its existing max level (5): XP may keep accruing but the level never exceeds it.

This makes Skill mutable per-Staffer session state rather than static content, which needs a home in `GameState` (distinct from the loaded-once `staffers.json` catalog) and in the save schema. Mined from vision-chunk-2's hybrid training model (ADR-0006), translated to this game's vocabulary; training stays free rather than adopting a cash/Hearts cost, matching the source spec.

Status: accepted, supersedes the Hearts+cash training cost sketched in `hotel_habitat_plan.md` §3.5 and the `CONTEXT.md` Hearts definition.
