# 09 — Staff Job travel animation (Housekeeping/Kitchen)

**What to build:** Generalize today's decorative, non-spatial bellhop/housekeeper round-trip animations into real point-to-point moves tied to actual sim state. A Housekeeping Staffer with an in-flight cleaning Job visibly travels from their Station to the real Room cell they're cleaning and stays there until the Job resolves, then returns. A Kitchen Staffer with an in-flight breakfast/dinner Job does the same to the real Diner actor on the Terrace floor they're serving. Reassigning a Staffer mid-Job (interrupting it, per existing behavior) cancels their travel and returns them to their new Station/the Staff Pool.

**Blocked by:** 03, 04, 06

**Status:** ready-for-agent

- [ ] A Housekeeping Staffer who claims a dirty Room's cleaning Job visibly travels from their Station to that Room's real cell and remains there until the Job completes
- [ ] A Kitchen Staffer who claims a breakfast or dinner Job visibly travels to the real Diner actor they're serving on the Terrace floor and remains there until the Job completes
- [ ] A Staffer stacked onto an in-progress Job (a second Staffer joining) also travels to the same real target
- [ ] Reassigning a Staffer off a Station they're mid-Job on interrupts their travel immediately and returns their actor to their new Station or the Staff Pool, without affecting any other Staffer's in-flight Job or travel
- [ ] A Staffer with no in-flight Job idles at their Station (or the Staff Pool if unassigned), never mid-travel with nothing to do
