# 06 — Ground floor: Station posts, the staff nook, and Staffer assignment

**What to build:** Staffing becomes placing someone somewhere. Each of the three Stations is a physical post: Housekeeping a supply closet at the lobby's existing door, Reception a front desk, Kitchen the Terrace pass upstairs (ADR-0010 unchanged). The desk, closet and nook are placeholder props at their contract anchors over the current lobby art — real lobby art drops into the same slots later with no code change.

An assigned Staffer stands at their post; a Staffer with no Station loiters in a staff nook beside the desk, so who is free is answered by looking. Dragging a Staffer onto a post assigns them through the existing `GameState.reassign_staffer()`/`Sim.assign_staffer()` path, and tapping one still opens their Skill/Trait detail. The hit target for a post is decided per target — a thin invisible Control in front of the art, or an `Area2D` with hand-rolled drag, whichever is cheaper — the constraint is that the gesture works, not which node type serves it.

The layout model gains actor placement bucketing: which post, nook or band each Staffer belongs to.

**Blocked by:** 01, 06

**Status:** ready-for-agent

- [ ] Three Station posts are drawn at their anchors: supply closet, front desk, Terrace pass
- [ ] An assigned Staffer stands at their post, and reassigning moves them there
- [ ] Unassigned Staffers stand in the staff nook
- [ ] Dragging a Staffer onto a post assigns them via the existing GameState/Sim path, with no new Sim state
- [ ] Tapping a Staffer opens their existing Skill/Trait detail
- [ ] A Station's staffing level is readable from the sprites standing at it, with no card to count
- [ ] Staffer placement bucketing is covered by tests against the pure layout model
