# 12 — Staffer Job travel and Stacking

**What to build:** "Who is cleaning what" answered by looking. A Staffer working a Housekeeping Job leaves their post, uses the elevator like a guest does, walks to the actual Room they are cleaning, and works there — with the mess visibly disappearing as the Job progresses — then returns. A Staffer working a Kitchen Job is at the Terrace pass. Dragging a second Staffer onto an in-progress Job Stacks them onto it, preserving ADR-0008's gesture, and both Staffers travel to the same target.

Reassigning a Staffer mid-Job interrupts their travel immediately and returns them to their new post or the staff nook, without disturbing any other Staffer's Job. A Staffer with no Job in flight idles at their post, never mid-travel with nothing to do. The working state is the Staffer's one context animation; Manny sweeps.

As with the guest journey, all timing comes from the existing Job durations — travel is presentation only.

**Blocked by:** 07, 08, 09, 12

**Status:** done

- [x] A Housekeeper claiming a Job travels by elevator to that actual Room and works there until it completes
- [x] The Room's mess visibly clears as the Job progresses
- [x] A Kitchen Staffer working a Job is at the Terrace pass
- [x] Dragging a second Staffer onto an in-progress Housekeeping or Kitchen Job Stacks them, and both travel to the same target
- [x] Reassigning a Staffer mid-Job cancels their travel and returns them to their new post or the nook, affecting no other Staffer
- [x] A Staffer with no Job idles at their post or in the nook
- [x] Stacking validity comes from the existing `Sim.can_stack_*` functions, with no rule duplicated in the view

## Comments

Implemented in `ui/hotel_world.gd`'s new "Staffer Job travel" section (ticket 13): a Housekeeping Staffer's travel reuses `_play_ride_legs()` verbatim -- the same walk/ride/walk shape ticket 12's guest elevator journey already established -- keyed by `staffer_id` (not room, since a Stacked pair travels to the same target independently) in a new `_staffer_travel` dict. Detection is polled every frame against `Sim.cleaning_job()` (`_sync_staffer_travel()`) rather than event-driven, since Housekeeping/Kitchen Jobs fire no per-Job start/end signal of their own. A Job that disappears is "resolved" (plays a return trip) if its Room's `needs_cleaning` actually cleared, or "interrupted" (freed on the spot, no return trip) otherwise -- covering both a natural completion and a reassignment/Stack-elsewhere. `_rebuild_staffers()` skips any staffer_id tracked in `_staffer_travel` so the ordinary post/nook render never double-draws them.

A Kitchen Staffer needs no travel: Kitchen's own Station post (`sim/building_layout.gd`'s `STATION_POST_ANCHOR_NAME`) already sits at the Terrace pass, so `_rebuild_staffers()` just swaps that Staffer's `CharacterSprite` to the existing `"working"` state (`_kitchen_job_active()`) while a breakfast/dinner Job keeps them busy -- no new anchor or movement needed.

Stacking is wired into `_end_staffer_drag()`: after the existing Station-post-drop reassignment check, a drop on a built Room bay tries `Sim.can_stack_staffer_on_room()`/`stack_staffer_on_room()`, and a drop on a served Terrace diner (`ui/diner_actor.gd`'s new `hit_rect()`) tries `Sim.can_stack_staffer_on_dinner()`/`stack_staffer_on_dinner()` -- no rule re-derived in the view. Breakfast Stacking-by-drag isn't wired: no breakfast entry has an on-screen diner actor anywhere in this codebase today (only `Sim.walkin_queue`/dinner service is rendered via `_diner_actors`), so there's nothing to drop a Staffer onto for that case; a Kitchen Staffer's `"working"` state itself still covers breakfast via `_kitchen_job_active()` checking both `Sim.breakfast_job()`/`Sim.dinner_job()`.

The mess-progress checklist item ("visibly clears as the Job progresses") is a presentation-only fade: `sim/building_layout.gd` stays untouched (mess/dirty is still a pure `room` field), but `ui/hotel_world.gd`'s `_room_mess_progress()` interpolates `ui/room_bay_actor.gd`'s mess overlay alpha against the SAME `Sim.cleaning_job()` `ticks_remaining` countdown the travel polling already reads, using a per-staffer `total_ticks` baseline snapshotted once at claim time (Stacking's own recompute can only lower or match that baseline, since summed Skill's lookup is non-increasing, so progress never runs backwards). `_rooms_signature()` folds in a new `_cleaning_progress_signature()` so a Job progressing (no `hotel_rooms` mutation of its own) still re-triggers `_rebuild_room_bays()` every tick -- the same full-rebuild-every-tick trade-off `_lobby_signature()`/`_dining_signature()` already make for Patience decay.

New pure-function test: `tests/test_housekeeper_travel_placement.gd` covers `sim/building_layout.gd`'s new `resolve_room_housekeeper_point()` (where a Housekeeping Staffer stands in a Room bay, distinct from the guest occupant grid), matching `tests/test_room_occupant_placement.gd`'s shape. Per spec.md's Testing Decisions, the travel/Stacking/mess-fade behaviour itself was verified with a throwaway, uncommitted GUT test driving a live `HotelWorld` through claim/stack/reassign-interrupt/complete-and-return and confirming the mess-progress fade, then discarded -- the same "playtest-verified, not unit-tested" treatment ticket 12 gave the elevator journey.

Full suite: 250 tests, 237 passing, 13 pre-existing failures -- same set prior tickets' runs already confirmed unrelated (batch-runner-autopilot, checkout-review, day-night-cycle, hotel-background-slices, integration-multiday, manual-seating, room-guest-dinner-addon).
