Status: ready-for-agent

# The hotel as a drawn world: Node2D building, camera, and sprite actors

## Problem Statement

The player never sees their hotel. They see a vertically-scrolling stack of Control panels made of text buttons — a Reception queue of party cards, a row of Staffer/Station cards, a grid of Room cells, a Terrace queue list — with three screen-space overlay layers hand-tweening colored rectangles between them. ADR-0016 called this a "spatial building cross-section", and structurally it is one, but every object in it is a `Button` with a `StyleBoxFlat` on it. Nothing is drawn. The Match puzzle, the Housekeeping Job, the Terrace rush — all of it reads as a form being filled in.

ADR-0018 recorded this complaint verbatim ("still reads as a menu, not a visual interface", "can't see the whole hotel in one view"), named the pan/zoom camera rewrite as the fix, and then deliberately deferred it in favour of a scoped auto-scroll patch — a patch that was never implemented either. Two problems follow from the deferral:

- **The hotel has no single view.** Once the building overflows the viewport, a Party dragged from Reception at the bottom physically cannot reach a Room floor at the top, because a Godot GUI drag cannot scroll the container it started in. The building's overall state — how full, how dirty, how staffed — is never visible at once.
- **The composition the game wants is not expressible.** A box-model layout cannot draw an elevator shaft spanning floors, planters breaking a floor line, a building frame around the whole stack, or a night skyline behind it. Every such element needs an absolute-positioned escape hatch, which is how ~850 lines of overlay layer (`room_occupancy_layer`, `staff_job_travel_layer`, `toast_layer`) came to exist: they already simulate a 2D scene graph on top of a Control tree, re-deriving world positions from `get_global_rect()` on every frame.

## Solution

Rebuild the play surface as an actual 2D scene. The building becomes a `Node2D` world framed by a `Camera2D`; Control survives only for the HUD strip and the modals. Floors, Rooms, Stations, the elevator, and every Guest and Staffer become sprites placed in world space, with a documented asset contract so real art drops into fixed slots without code changes.

The building reads bottom-to-top: **Ground Floor Reception**, then the **Terrace at Level 1**, then one Room-type **Floor** per unlocked type stacked above in ascending unlock-Star order. Each Room floor holds exactly two bays. Every Station becomes a physical post a Staffer stands at — a supply closet, the front desk, the Terrace pass — and unassigned Staffers loiter in a staff nook beside the desk. The elevator carries guests and travelling Staffers between floors for real.

The camera defaults to framing the whole hotel, so "how is my hotel doing" is one glance. Pinch/scroll zooms in for detail; drag pans; a control resets to fit-all. During a drag, holding near a screen edge pans the camera, so any floor is reachable from Reception at any zoom.

State is read from the art, not from chrome. A Guest's **Patience** is an always-visible mood face that sours from content to impatient to huffy; their **Needs** appear as a bubble of Tag icons when tapped or picked up. A Room bay shows occupancy as guest sprites inside it, dirtiness as a mess overlay a Housekeeper animates away, an upgrade as a prop, and a Match hint as a coloured glow on its frame.

The building's shell art exists — `assets/hotel-background.jpg`, a painted five-band cross-section — and is sliced into tiling parts so the building can compose itself to any floor count. Character art does not exist, so the asset contract ships first and every slot without art renders a correctly-sized labelled placeholder until its sprite lands. `marlon` is renamed to `manny` and his existing walk/sweep art becomes the contract's reference implementation — the one real asset that proves the pipeline.

Two Sim-layer changes, both deliberate. A `max_instances` cut from 4 to 2, so a floor's two drawn bays and the build rules agree. And the **Bellhop Station and its Escort Job are removed outright** — the hotel runs on three Stations, and a seated Party reaches its Room on the existing unstaffed path — rather than being drawn into a world that would then have to unlearn them. No other Sim behaviour changes.

## User Stories

### Seeing the hotel

1. As a player, I want the whole hotel framed on screen by default, so that I can judge how full, dirty and busy it is in one glance instead of scrolling to find out.
2. As a player, I want to pinch or scroll to zoom into a floor, so that I can see what individual guests are doing when I care to.
3. As a player, I want to drag to pan the view when zoomed in, so that I can move around a tall hotel without losing my zoom level.
4. As a player, I want a single control that returns the camera to framing the whole building, so that I am never lost in my own hotel.
5. As a player, I want the game to run in a portrait window shaped like a phone, so that a tall building fills the screen the way the design intends.
6. As a player, I want each floor drawn as a place with its own themed interior, so that the hotel reads as a building rather than a table of rows.
7. As a player, I want a small painted sign on each floor reading its level number and Room type, so that I can tell an Ice Grotto floor from a Lagoon Room floor without opening anything.
8. As a player, I want the Terrace to sit permanently at Level 1 directly above Reception, so that it never moves as my hotel grows and I always know where to look for dining.
9. As a player, I want Room floors ordered bottom-to-top by ascending unlock Star, so that my building visibly grows more impressive as I progress.
10. As a player, I want a newly unlocked Room type to add its floor on top without renumbering the floors below it, so that a floor I have learned the position of stays where it was.
11. As a player, I want the sky behind the building to change with the time of day, so that I can feel the Morning/Midday/Evening/Night phase without reading a label.
12. As a player, I want an elevator shaft drawn through the building, so that the hotel has a visible circulation spine rather than characters sliding across the facade.

### Guests and the Match puzzle

13. As a player, I want arriving Parties to stand in the lobby as individual animal characters, so that I can see who has turned up without opening a list.
14. As a player, I want a Party of three to appear as three characters standing together, so that party size is something I see rather than read.
15. As a player, I want a mood face floating above every waiting guest at all times, so that I can spot who is about to walk out from across the whole hotel.
16. As a player, I want that mood face to visibly sour as Patience decays through content, impatient and huffy, so that urgency is continuous rather than a number crossing a threshold.
17. As a player, I want tapping a waiting guest to pop a bubble of Tag icons showing their Needs, so that I can solve the Match puzzle without a text card.
18. As a player, I want picking a guest up in a drag to show that same Needs bubble, so that the two gestures teach me the same thing.
19. As a player, I want Rooms that satisfy the selected Party's Needs to glow green and partial matches to glow amber, so that the seating decision is made against the building itself.
20. As a player, I want to drag a guest onto a Room to seat them, so that seating feels like placing someone in a place.
21. As a player, I want tapping a guest and then tapping a Room to still seat them, so that I am never forced into a drag I cannot make.
22. As a player, I want holding a dragged guest near the top or bottom of the screen to pan the camera, so that I can reach any floor from the lobby no matter how far I am zoomed in.
23. As a player, I want a seated guest to walk to the elevator, ride it, and walk into their Room, so that I get to watch the outcome of the decision I just made.
24. As a player, I want seated guests to stay visible inside their Room for the whole stay, so that an occupied Room reads as occupied from across the building.
25. As a player, I want guests to sleep with a Zz at Night, so that the hotel feels inhabited rather than staged.
26. As a player, I want a turned-away Party to walk back out of the lobby, so that a lost booking is as legible as a won one.
27. As a player, I want a checking-out guest to leave their Room, ride down and walk out, so that checkout is the visible mirror of check-in.

### Rooms

28. As a player, I want each Room floor to show two bays, so that the floor composition is stable and readable at any hotel size.
29. As a player, I want an unbuilt bay drawn as a Build Slot I can tap to construct, so that expanding the hotel is a thing I do to the building.
30. As a player, I want a dirty Room to show visible mess after a checkout, so that I know what needs Housekeeping without checking a queue.
31. As a player, I want that mess to visibly disappear as a Housekeeper works, so that cleaning progress is something I watch rather than infer.
32. As a player, I want a purchased upgrade to add a visible prop to the Room interior, so that spending Hearts changes what I see.
33. As a player, I want a small door plate showing each Room's number, so that I can connect a toast or a review to the Room it came from.
34. As a player, I want tapping an occupied Room to still show me the stay's details, so that I lose no information by moving to a visual view.

### Staff and Stations

35. As a player, I want each of the four Stations drawn as a real post in the building — a supply closet, the front desk, a luggage cart, the Terrace pass — so that staffing is placing someone somewhere.
36. As a player, I want unassigned Staffers loitering in a staff nook beside the desk, so that I always know who is free.
37. As a player, I want to drag a Staffer onto a Station post to assign them, so that staffing uses the same gesture as seating.
38. As a player, I want an assigned Staffer to stand at their post, so that a Station's staffing level is visible without counting cards.
39. As a player, I want a Staffer working a Housekeeping Job to walk to the actual Room they are cleaning and work there, so that "who is cleaning what" is answered by looking.
40. As a player, I want a Staffer working a Kitchen Job to be at the Terrace pass, so that dining staffing is as legible as room staffing.
41. As a player, I want to drag a second Staffer onto an in-progress Job to Stack them, so that ADR-0008's Stacking gesture survives the rebuild.
42. ~~As a player, I want a Bellhop to visibly escort a guest to their Room via the elevator.~~ Withdrawn — the Bellhop Station and the Escort Job are removed before the rebuild starts. Story numbering below is left unchanged.
43. As a player, I want travelling Staffers to use the elevator like guests do, so that the building's circulation is consistent.
44. As a player, I want tapping a Staffer to still open their Skill/Trait detail, so that nothing about roster management regresses.
45. As a player, I want Manny drawn with his real walk and sweep animation, so that at least one character in my hotel is properly alive.

### The Terrace

46. As a player, I want the Terrace drawn as a bistro with tables, so that dining is a place in my hotel.
47. As a player, I want served and seated diners to sit at those tables as characters, so that a busy dinner service looks busy.
48. As a player, I want waiting diners to queue at the terrace entrance with the same mood faces as lobby guests, so that dining Patience is read the same way everywhere.
49. As a player, I want tapping the terrace signage to open the existing Daily Special, Kitchen staffing and upgrade controls, so that ADR-0010's tap-the-structure pattern is preserved.

### Feedback and the HUD

50. As a player, I want brief messages to appear near where an event happened, so that I connect feedback to the place that produced it.
51. As a player, I want an arrow marker at the screen edge when something happens outside my current view, so that zooming in never hides an event from me.
52. As a player, I want tapping that marker to pan the camera to the event, so that following up on a notification is one gesture.
53. As a player, I want Cash, Hearts, my Star rating with Reputation as its fill, and the day and season, pinned at the top, so that I never lose sight of the hotel's vitals.
54. As a player, I want the speed and pause controls reachable from the gear, so that the HUD stays as calm as the design intends.
55. As a player, I want modals that still exist to be styled like the rest of the game, so that opening one does not feel like leaving it.

### Development-facing

56. As a developer, I want one pure module that decides what the building should look like, so that the drawn layer is a dumb projection and every interesting bug has one place to be tested.
57. As a developer, I want a documented asset contract fixing each sprite slot's size, anchor, naming and animation states, so that art can be produced against it and dropped in without touching code.
58. As a developer, I want a missing sprite to fall back to a correctly-sized labelled placeholder, so that the game is always playable and layout is validated against real footprints before art exists.
59. As a developer, I want the game playable at every commit with a toggle between the old and new views, so that a 2,000-line view replacement never leaves the project broken.
60. As a developer, I want every existing `Sim` and `GameState` call to keep its signature, so that a presentation rewrite does not ripple into the simulation.

## Implementation Decisions

### Architecture

- **A `Node2D` world replaces the Control tree for the building.** `main_screen.gd` keeps the HUD strip and the modal/popup hosts as Controls and mounts a hotel-world node in place of `hotel_view.gd`'s `ScrollContainer`. The world holds a `Camera2D` and a building node; floors, bays, Station posts, the elevator, and actors are its children.
- **Retired at the end of the migration:** `hotel_view.gd`, `hotel_panel.gd`, `reception_panel.gd`, `station_panel.gd`, `terrace_panel.gd`, `staffer_card.gd`, `station_card.gd`, `room_occupancy_layer.gd`, `staff_job_travel_layer.gd`, and the Control-space parts of `toast_layer.gd` — roughly 2,000 lines. The three overlay layers exist only to hand-roll world positioning inside a box-model layout; a real scene graph removes their reason to exist.
- **Hit targets are decided per target, not by blanket rule.** Godot's `_get_drag_data`/`_can_drop_data`/`_drop_data` API is Control-only; a target may keep a thin invisible Control in front of its art, or move to `Area2D` with hand-rolled drag, whichever is cheaper for that target. This is deliberately not fixed up front — the constraint is that both gestures work, not which node type serves them.
- **Project settings** move to a portrait mobile viewport of roughly 720×1280 with `canvas_items` stretch and `expand` aspect, so desktop windows letterbox rather than reflow. Textures import with nearest-neighbour filtering for pixel art.

### The one seam: a building layout model

- **A new pure module derives the entire visual description of the building from `GameState`/`Sim` state.** It is a `RefCounted` of static functions with no node or autoload dependencies, mirroring `sim/match_hint.gd`'s shape, and the renderer consumes its output without deriving anything of its own.
- It answers: the ordered list of floors bottom-to-top with each floor's level number, Room type and sign text; each floor's two bays and whether each is a built instance, a Build Slot, or empty shell; each bay's visual state (clean, occupied, dirty, upgraded) and its Match hint colour for a given selected Party; the placement bucket for every actor (a Room bay, a Station post, the staff nook, the lobby queue, a Terrace table); the fit-all camera bounds for a given building height; and the resolution of an asset slot to a real path or its placeholder fallback.
- **Floor ordering** is ascending `unlock.star` from `data/rooms.json`, ties broken by array order in that file. Level numbers are assigned from this ordering with the Terrace occupying Level 1, so a newly unlocked floor stacks on top and never renumbers the floors below. Reception is the Ground Floor and is not numbered.
- **Match hint and Stacking validity are not re-derived.** The layout model calls the existing `Sim.match_hint()`, `Sim.can_stack_staffer_on_room()`, `Sim.can_stack_staffer_on_breakfast()` and `Sim.can_stack_staffer_on_dinner()` and surfaces their answers as per-bay/per-target render state. Those functions remain the single authority.

### Camera and drag

- The camera's default framing is the whole building's fit-all bounds, recomputed when a floor is added. Pinch and scroll adjust zoom within clamped bounds; drag pans; a HUD control eases back to fit-all.
- **Drag reachability is auto-pan at screen edges.** While a drag with a party or staffer payload is in progress, holding the pointer near the top or bottom edge pans the camera at a steady rate. This was chosen over easing the camera to fit-all on pickup; the known cost is that a long traverse is slow and the target floor is not visible until it scrolls in.
- Picking up a Party in a drag puts it into the same selected state a tap produces, so the Needs bubble and the green/amber bay glow appear for both gestures. ADR-0001 and ADR-0009 are otherwise untouched: tap-then-tap and drag coexist, and there is still no auto-matcher.

### Floors, bays, and the room cap

- **`max_instances` drops from 4 to 2 for every Room type in `data/rooms.json`.** This is one of the spec's two Sim-layer changes. Two drawn bays and the build rules must agree; a view that caps below the data guarantees Rooms that exist but cannot be seen or seated. The hotel's ceiling falls from 24 Rooms to 12, which is accepted as a real balance change for now — no compensating retune is in scope. `SaveManager` is an unimplemented stub, so there is no migration cost.
- A floor draws its built instances in bay order, then a Build Slot in the next bay if `GameState.can_build_more()` allows, then empty shell.
- Room bay state comes entirely from art: occupancy from guest sprites placed inside, dirtiness from a mess overlay driven by the room's cleaning flag, upgrades from props keyed to purchased upgrade ids, and Match hints from a glow on the bay frame shown only during a selection or drag. A small door plate carries the room number, derived from level and bay.

### Stations, the elevator, and actors

- **The three Stations become world posts:** Housekeeping a supply closet on the ground floor, Reception the front desk, Kitchen the Terrace pass (ADR-0010 unchanged). A post is a drop target for a staffer payload and calls the existing `GameState.reassign_staffer()`/`Sim.assign_staffer()` path. Staffers with no Station occupy a staff nook beside the desk.
- **The elevator is functional but presentation-only.** Actors travelling between floors path to the shaft, ride the car, and walk out onto the destination floor. All timing continues to come from the existing check-in and Job durations in `SimController` — the elevator introduces no capacity limit, no queueing rule, and no new Sim state. An actor whose Sim-side travel completes while the car is mid-flight is placed at its destination regardless; the animation never gates the simulation.
- **Actor animation states are idle, walk, and one context state** — sleeping for a Guest at Night, working for a Staffer at their Station. Room occupants take fixed spots in their bay; there is no wander behaviour and no ambient behaviour scheduler.
- **`marlon` is renamed to `manny`** across `data/staffers.json`, `GameState`, and every test — a hard rename with no back-compat alias, as ADR-0018 specified, since Staffer ids are internal string keys and nothing persists them. His existing walk and sweep sprites become the reference implementation the asset contract is validated against.

### The asset contract

- A documented contract fixes, per slot: the file path pattern, pixel dimensions, anchor point, frame count and animation states. Slots cover the building shell and elevator, per-Room-type floor and interior art, the Reception and Terrace floors, Station post props, per-Species guest sprites, per-Staffer sprites, the eight Tag icons, mood faces, and HUD pills.
- **A missing asset renders a placeholder occupying the identical footprint**, tinted per species/room type and carrying a short label such as a species abbreviation or room number. This is deliberately temporary text so the Match puzzle is playtestable before art exists; each label disappears when its slot's asset lands. Resolution and fallback live in the layout model, so the renderer never checks for a file.
- `character_idle.png`/`.webp` and the two UUID-named PNGs currently in `assets/` are treated as unused leftovers and get no slot.

### HUD, toasts, and modals

- The HUD is four slots plus a gear: Cash, Hearts, a Star pill with Reputation rendered as its fill (Reputation being defined as progress within a Star), and a day/season chip. Pause/1x/2x move behind the gear.
- **Toasts keep their spatial anchor**, now a world position projected through the camera rather than a Control rect. An event whose anchor is outside the current framing raises a small arrow marker on the corresponding screen edge; tapping it pans the camera to the anchor. The retired day-log ticker is not revived.
- **Every existing modal survives** — seat-confirm, build-confirm, stay-info, staffer-detail, upgrade, terrace, and the reception admin tabs (prices, hire, reports, reviews) — as Control panels reskinned with a pixel-art theme sharing the world's palette and font. Their content and their `Sim`/`GameState` calls are unchanged. Moving any of them into the world is explicitly deferred to a later review pass in which each surviving modal is individually justified.

### Migration

Delivery is staged so the game is playable at every commit, with a development toggle selecting the old or new view:

1. Sim and data prep against the old view: the Bellhop/Escort removal, the `marlon`→`manny` rename, the `max_instances` cut
2. Slicing the background painting into tiling contract slots
3. World scaffold, camera, and portrait viewport
4. The asset contract, the anchor registry, character slots, placeholders, and Manny
5. Ground floor Stations and the staff nook; Room floors, bays and Build Slots; the Terrace
6. Lobby guests, mood faces, Needs bubbles
7. Tap and drag, Match hints, auto-pan
8. Elevator, guest journeys, Staffer Job travel, Stacking
9. HUD, toasts, edge markers, modal reskin
10. Deletion of the retired scripts and the toggle

### ADR bookkeeping

A new ADR supersedes **ADR-0016** (whose Control-tree rendering model this replaces) and **ADR-0018** (whose auto-scroll decision is obsoleted by the camera and was never implemented, and whose Manny decision is executed here). A second ADR records the Bellhop removal and supersedes **ADR-0014** (Bellhop-escorted check-in) and **ADR-0017** (its implementation). ADR-0001, 0004, 0005, 0008, 0009, 0010 and 0011 are unaffected. ADR-0015's constraint — that the animation system accept a new sprite set per Staffer/task without redesign — is honoured by the asset contract and is now closed.

## Testing Decisions

- **A good test here asserts what the building should look like, never how it is drawn.** It feeds literal state in and checks the described layout out. It does not touch nodes, tweens, positions in pixels, camera easing, or hit geometry.
- **The building layout model is the only new seam and the only new test target.** Prior art is `tests/test_match_hint.gd`, which tests `sim/match_hint.gd`'s pure static functions with hand-built literal dicts and no autoloads; these tests take the same shape. `tests/helpers/sim_test_base.gd` remains available for any case that genuinely needs the live autoloads, but the layout model is designed so that none should.
- **What is covered:** floor ordering by ascending unlock Star with array-order tie-breaking; level number assignment and its stability when a new floor unlocks; bay-to-Room-instance mapping including the Build Slot and empty-shell cases; the per-bay visual state derived from occupancy, cleaning and upgrade state; the Match hint colour surfaced per bay for a given Party; actor placement bucketing; fit-all camera bounds for a given building height; and asset slot resolution with its placeholder fallback.
- **What is deliberately not covered:** sprite positioning, tween and animation timing, camera easing and zoom clamping, elevator movement, drag hit-testing, and modal rendering. These stay playtest-verified, as every prior UI ticket in this repo has been.
- **The existing suite must stay green unchanged**, apart from the mechanical `marlon`→`manny` rename, any assertion that depends on `max_instances` being 4, and the Bellhop assertions removed with the Station itself (`tests/test_bellhop_escort.gd` is deleted).

## Out of Scope

- **Producing the art.** This spec delivers the contract, the slots and the placeholder fallback. Guest, Staffer, room, building and icon sprites beyond Manny's existing walk and sweep are separate work.
- **Layout for more than two Rooms per floor.** The cap is cut to 2 and the composition question for 3+ bays is deferred until the world is working.
- **Rebalancing for the halved room ceiling.** Capacity and demand tuning against 12 Rooms instead of 24 is a separate exercise.
- **Moving modals into the world.** Every modal survives as a panel; the review pass that justifies or removes each one is a later, separate effort.
- **Ambient per-species behaviour.** Actors get idle, walk and one context animation; wandering, multi-animation behaviour pools and a behaviour scheduler are not built.
- **Interior lighting by phase.** Only the sky tints; room and floor interiors keep constant lighting.
- **Elevator capacity and queueing.** The car is a visual conveyance with no limit and no effect on Sim timing.
- **Themed habitat names for floors.** Signs use the existing Room type name; no second naming vocabulary is added to `rooms.json` or `CONTEXT.md`.
- **Save/load.** `SaveManager` remains the stub it is today.
- **Any change to Sim behaviour** beyond the `max_instances` data edit and the Bellhop/Escort removal.
- **Landscape and responsive layout.** Portrait is the target; other aspect ratios letterbox.

## Further Notes

- **The auto-pan choice is a known trade-off.** Easing the camera to fit-all on drag pickup would have made every legal target visible for the whole drag and doubled as a "where can this go?" affordance. Auto-pan at edges was chosen instead; if a long lobby-to-top-floor drag proves tedious in playtest, revisiting this is a small, contained change since the drag payload and drop-target logic are unaffected either way.
- **The `max_instances` cut and the Bellhop removal are the two places this spec crosses the presentation-only boundary** that ADR-0016 drew and that this spec otherwise keeps. Both are done deliberately and visibly rather than papered over in the view: a Room the view cannot draw is a Room the player cannot seat, and an Escort animation built for a mechanic already marked for deletion is work thrown away twice.
- **Night is roughly five seconds of real time at 1x** (`Clock` runs a 60-second day across 240 ticks, with Night starting at tick 221). Sky transitions need easing tuned for that, and the sleeping-guest animation will be brief.
- **The old view's deletion is a ticket, not a side effect.** Keeping the toggle past step 8 would mean maintaining two view trees against every future `GameState` change; it is retired in the same change that removes the panels.
- **The three overlay layers are the strongest evidence for this rewrite.** `room_occupancy_layer.gd`, `staff_job_travel_layer.gd` and `toast_layer.gd` total ~850 lines whose job is re-deriving world positions from `get_global_rect()` and tweening against a full-rect screen-space Control. In a `Node2D` world, an actor walking from Reception to a Room is a tween on a child of the building, and a toast is a node parented to its anchor.
