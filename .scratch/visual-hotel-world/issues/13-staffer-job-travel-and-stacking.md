# 12 — Staffer Job travel and Stacking

**What to build:** "Who is cleaning what" answered by looking. A Staffer working a Housekeeping Job leaves their post, uses the elevator like a guest does, walks to the actual Room they are cleaning, and works there — with the mess visibly disappearing as the Job progresses — then returns. A Staffer working a Kitchen Job is at the Terrace pass. Dragging a second Staffer onto an in-progress Job Stacks them onto it, preserving ADR-0008's gesture, and both Staffers travel to the same target.

Reassigning a Staffer mid-Job interrupts their travel immediately and returns them to their new post or the staff nook, without disturbing any other Staffer's Job. A Staffer with no Job in flight idles at their post, never mid-travel with nothing to do. The working state is the Staffer's one context animation; Manny sweeps.

As with the guest journey, all timing comes from the existing Job durations — travel is presentation only.

**Blocked by:** 07, 08, 09, 12

**Status:** ready-for-agent

- [ ] A Housekeeper claiming a Job travels by elevator to that actual Room and works there until it completes
- [ ] The Room's mess visibly clears as the Job progresses
- [ ] A Kitchen Staffer working a Job is at the Terrace pass
- [ ] Dragging a second Staffer onto an in-progress Housekeeping or Kitchen Job Stacks them, and both travel to the same target
- [ ] Reassigning a Staffer mid-Job cancels their travel and returns them to their new post or the nook, affecting no other Staffer
- [ ] A Staffer with no Job idles at their post or in the nook
- [ ] Stacking validity comes from the existing `Sim.can_stack_*` functions, with no rule duplicated in the view
