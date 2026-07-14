# Build-menu rework, staggered lobby activity, and a housekeeping character

## Context

Playtesting turned up three UX/liveliness issues in the Godot/GDScript hotel
sim (`C:\Users\Richard\projects\habitat-hotel`):

1. The Build menu (`ui/build_menu.gd`) embeds a full copy of the 3x6 room grid
   (`HotelPanel`) just so the player can pick an empty slot, then shows the
   room catalog below it. In the modal's fixed size, the grid eats most of
   the space and the catalog rows (the actual decision) get cramped.
2. Guest arrivals/checkouts are decided by the sim in one instant per phase
   (`autoload/sim_controller.gd`'s `_do_morning`/`_do_midday`), and today's
   `LobbyView` (`ui/lobby_view.gd`) plays every resulting animation starting
   at the same moment, so a busy day reads as one dump of guests rather than
   a living lobby.
3. There's no housekeeping presence: rooms go instantly from occupied to
   available on checkout, and the design doc's Chunk 4 "Housekeeper" role
   (room condition, wages, training) hasn't been built yet.

Decisions already made with the user (via clarifying questions):
- The menu-bar "Build" button is **removed**; Build is only reachable by
  tapping an empty slot, and the menu it opens is **locked to that slot**
  (no in-menu slot switching -- close and tap elsewhere to change).
- Staggering is **presentation-only**: the sim keeps resolving a phase's
  matches/checkouts in one instant (this preserves Chunk 1's deterministic
  batch-runner behavior used for balance testing). `LobbyView` queues the
  already-decided events and drip-feeds their animations across that
  phase's real remaining time, so nothing here changes economy/matching.
- The housekeeper is a **real mechanic**, not just cosmetic: checkout marks
  a room dirty and it's excluded from matching until cleaned. This is a
  deliberate, scoped-down slice of the Chunk 4 Housekeeper idea (no named
  staff record, no wage, no traits/training yet -- just the room state and
  a visual actor), and it does change turnover timing, so it needs a
  batch-runner sanity check against Chunk 1's tuned cash-survivability
  target.

---

## 1. Build menu: tap-to-open, no embedded grid

**`ui/main_screen.gd`**
- `_build_menu_bar()` (~L139-147): delete the `["Build", ...]` entry.
- `_on_hotel_slot_selected()` (~L161-172): when `room.is_empty()`, construct
  `BuildMenu`, set its new `slot_index` before opening (same pattern already
  used for `UpgradeMenu.slot_index` two lines below), e.g.:
  ```gdscript
  var menu := BuildMenu.new()
  menu.slot_index = slot_index
  open_menu("Build (slot %d)" % slot_index, menu)
  ```
- Connect `menu.build_completed` (new signal, see below) to `close_menu`, so
  picking a room closes the modal instead of leaving an empty catalog open.

**`ui/build_menu.gd`**
- Remove `_hotel_panel` (`HotelPanel`), `_selected_slot`, `_on_slot_selected`,
  `_hint_label`/`_refresh_hint`, and the "Pick an empty, unlocked slot" label
  -- no grid lives in this menu anymore.
- Add `var slot_index: int = -1` (public, set by the caller before
  `add_child`, exactly like `UpgradeMenu.slot_index`).
- Add `signal build_completed`.
- Keep `_build_demand_panel()` (forecast + recently-turned-away) at the top
  -- it's useful context for "what do I build here" and isn't part of the
  grid-is-too-small complaint.
- `_refresh_catalog()`: unchanged logic, but `build_btn.disabled` now checks
  `GameState.cash < cost` only (slot is always valid going in); still guard
  in `_on_build_pressed` with `GameState.room_at_slot(slot_index).is_empty()`
  before calling `GameState.build_room(...)`.
- `_on_build_pressed()`: on success, emit `build_completed` instead of
  refreshing in place.

## 2. Staggered lobby playback (presentation-only)

All changes confined to **`ui/lobby_view.gd`**; no sim/`GameState` changes
for this part.

- Add `_event_queue: Array[Dictionary] = []` and a `Timer` (`_dequeue_timer`).
- The existing signal handlers (`_on_guest_seated`, `_on_guest_turned_away`,
  `_on_guest_checked_out`, plus the new `_on_room_marked_dirty` from part 3)
  become thin: they push a `{"kind": ..., args...}` dict onto `_event_queue`
  instead of animating immediately. Rename their current bodies to
  `_play_guest_seated(...)`, `_play_guest_turned_away(...)`,
  `_play_guest_checked_out(...)`, `_play_room_dirty(...)` -- unchanged
  internally, just invoked later by the dequeuer.
- `_dequeue_timer` timeout handler: pop one queued event (if any) and call
  its matching `_play_*`. Then reschedule: compute seconds remaining in the
  current phase from `Clock.tick_in_day`, `Clock.current_phase`,
  `Clock.PHASE_START_TICKS`, and `Clock.TICK_DURATION / Clock.speed`
  (reusing Clock's own phase table rather than duplicating durations), and
  set `wait_time = clamp(remaining_seconds / (queue.size() + 1), 0.35, 1.5)`.
  This spreads a big batch evenly across what's left of the phase and still
  paces a lone event sensibly.
- Pause/resume `_dequeue_timer` on `EventBus.clock_paused_changed`, so
  playback halts exactly when the rest of the game does (opening a menu).
- Move the existing `_send_bellhop()` call out of the old
  `_on_guest_seated` and into `_play_guest_seated`, so bellhop trips stagger
  with the guest walk they belong to instead of firing on the old
  immediate-signal timing.

## 3. Housekeeper: dirty rooms + a cleaning character

**Data model (`autoload/game_state.gd`)**
- Add `"needs_cleaning": false` to the room dict literals in
  `_build_starting_hotel()` (~L120-128) and `build_room()` (~L178).

**Sim (`autoload/sim_controller.gd`)**
- `_checkout_guest()` (~L213-259): after clearing `occupant`/etc., set
  `room["needs_cleaning"] = true` and emit the new
  `EventBus.room_marked_dirty(g["room_slot_index"])`.
- `_do_evening()` (~L146-147, currently `pass`): iterate
  `GameState.hotel_rooms`; for each with `needs_cleaning == true`, clear it
  to `false` and emit `EventBus.room_cleaned(int(room["slot"]))`. Update the
  stub comment (Evening is no longer a no-op -- it's now also "housekeeping
  finishes the day's turnovers"). Net effect: a room checked out in the
  Morning is unavailable through that day's Midday match and reopens the
  next day -- a deliberate one-day turnover delay.

**Matching (`sim/matcher.gd`)**
- `decide()` (~L28): extend the `vacant` filter to
  `r["occupant"] == null and not r.get("needs_cleaning", false)` so dirty
  rooms are correctly excluded from candidates.

**Signals (`autoload/event_bus.gd`)**
- Add `signal room_marked_dirty(slot_index: int)` and
  `signal room_cleaned(slot_index: int)` alongside the other per-event
  guest signals, with the same "cosmetic/derived, not source of truth"
  framing in the comment.

**Grid feedback (`ui/hotel_panel.gd`)**
- `refresh()` (~L50-88): in the "room built" branch, when
  `room["occupant"] == null and room.get("needs_cleaning", false)`, show a
  "(cleaning)" suffix, a distinct dusty modulate color, and a tooltip
  ("Being cleaned by housekeeping") instead of the plain vacant look.

**Visual actor (`ui/lobby_view.gd`)**
- Add a `_housekeeper` actor next to the existing `_bellhop`, own color and
  Y offset, stationed at Reception.
- Connect `EventBus.room_marked_dirty` to `_on_room_marked_dirty` (queues a
  `"dirty"` event, per part 2). `_play_room_dirty(slot_index)` sends the
  housekeeper on a reception -> elevator -> reception trip (mirrors
  `_send_bellhop()`), standing in for "went and cleaned that room" the same
  way the elevator already stands in for "now in their room" elsewhere in
  this file. `room_cleaned` doesn't need its own animation (the trip itself
  already sold "cleaning happened"); connect it only if useful for a log
  line, otherwise skip.
- Ambient idle: since this view is an abstract strip (Entrance/Reception/
  Elevator), not a real hotel map, "wanders around tidying" is represented
  as a small recurring idle nudge/bounce at Reception whenever the
  housekeeper isn't mid-trip (a repeating tween on a timer, skipped while
  `_housekeeper_tween` is active) -- consistent with how this file already
  abstracts physical space.

---

## Verification

- Open the project in Godot, run the main scene:
  - Tap an empty slot -> Build opens directly to that slot's catalog, no
    grid inside it; menu-bar no longer has a "Build" button; building a
    room closes the modal and the grid shows the new room.
  - Let a day run at 1x/2x: confirm arrivals/checkouts/turn-aways play out
    spaced across Midday/Morning instead of all at once, and playback
    pauses when a menu is opened.
  - Watch a guest check out: room shows "(cleaning)" in the grid, the
    housekeeper makes a cleaning trip, and the room is not offered to new
    arrivals until it clears at Evening; confirm it's biddable again next
    day.
- Run the headless batch tool for 60 days before/after (`BatchRunner.run`)
  and compare `debug_output/batch_report.csv` end-of-run cash against
  Chunk 1's tuned target (roughly -500 to +3000 on default policy) to make
  sure the one-day cleaning delay didn't push the economy out of range;
  note any drift for the user rather than silently re-tuning `balance.json`.
- Check the Godot console for warnings/errors (unconnected signals, null
  refs) during all of the above.
