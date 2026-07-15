# Decisions Log

Judgment calls made where the Chunk 1 brief was ambiguous or silent, per
Part B: "If this document is ambiguous on a detail, choose the simplest
option consistent with the pillars, and record the decision here."

## Repo history

- The repo already contained an unrelated earlier prototype ("Grand Safari
  Hotel") built from a different, no-longer-current design doc
  (`legacy/hotel_habitat_plan.md`). Its core interaction was an auto-matcher
  driven by a policy setting, and it already implemented Hearts, reputation,
  reviews, pricing tolerance, and in-progress staff/upgrades — all of which
  directly contradict this brief's Pillar 1 (manual matching is the game)
  and Part H (progression systems are out of scope for M1). Confirmed with
  the user that it should be preserved for reference under `legacy/` rather
  than adapted, and that Habitat Hotel would be built fresh at repo root.

## Environment

- Could not install or verify a Godot 4.x binary in this sandboxed session
  (network policy blocks github.com releases, tuxfamily.org, Flathub, and
  Snap; apt only has Godot 3.5.2). Targeted the Godot 4.3 stable API surface
  from documentation/training knowledge. `PINNED_VERSION.md` records this
  and what the user needs to do to verify. **The headless test suite has not
  been executed against a real engine in this session** — see
  `PINNED_VERSION.md` and `PLAYTEST.md` for the required follow-up.

## Data

- `data/balance.json` additionally encodes `starting_hotel` (grid size +
  prebuilt rooms) and `arrival_spread_fraction`, beyond the literal example
  in the brief's Part D. The brief's principle ("zero magic numbers in
  code", "all content lives in data/*.json") implies these belong in data
  too, even though Part D describes the starting hotel in prose rather than
  as a JSON block.

## Engineering: global class_name resolution

- Every cross-file reference between `sim/` and `tests/` scripts uses an
  explicit `const Foo = preload("res://path/foo.gd")` rather than relying on
  GDScript's global `class_name` symbol resolution. Godot 4 only resolves
  global class names via a project-local cache (`.godot/global_script_class_cache.cfg`)
  that is normally built by opening the project in the editor at least once;
  a pure `godot --headless --script ...` run against a project that has
  never been opened in the editor can fail to resolve bare global class
  names. Since this session could not run Godot at all to verify either
  way, explicit preloads remove the risk entirely at negligible cost.
  `class_name` declarations are kept on every file too, for editor
  ergonomics (autocomplete, type hints) once the project is opened normally.

## Simulation rules (Part E ambiguities)

- **Fit evaluation vs. party size (Part E's "capacity ≥ party count being
  placed"):** read as capacity ≥ the sub-group that would actually be
  seated in that room (`min(remaining_party_count, room_capacity)`), not
  the whole remaining party. Under this reading, any vacant+clean room with
  capacity ≥ 1 is always a valid (glowing) GOLD/AMBER candidate, even for
  an oversized party — which is what lets the player initiate a party
  split by dragging onto a room too small for the whole group. The "too
  small for even a split remainder" clause in Part A only fires for a
  hypothetical capacity-0 room type, which doesn't exist in `rooms.json`.

- **Split vs. partial-seating penalties (Part A):** both are flat penalties
  applied once, at seating time, to the stay just created:
  - `party_split_satisfaction_penalty` applies to every room after the
    first one used by a given party (`rooms_used > 0` at seat time).
  - `partial_seating_satisfaction_penalty` applies whenever a seating
    leaves a remainder behind in the queue (`count_to_place < remaining`
    at seat time), regardless of what later happens to that remainder.
  - A remainder that later walks away never gets a stay/satisfaction
    record at all, so it costs nothing beyond the missed revenue — this
    satisfies "no penalty beyond the missed revenue" directly, with no
    retroactive mutation of the already-seated stay needed.

- **"Paused while held" vs. "soft-slow also applies globally" (Part
  A/E, patience):** resolved as a single global sim-speed value. Holding
  a guest sets `state.soft_slow = true`, which multiplies effective sim
  speed by `balance.speed_soft_slow` (0.3x) for *everything* — every
  queued party's patience, housekeeping, the phase timer — not just a
  per-guest pause for the held party. Simpler, and consistent with Part
  C's description of soft-slow as a clock-level speed value alongside
  pause/1x/2x.

- **Selection persistence (Part A/G, "tap/press... soft-slows... while
  held/selected"):** implemented as toggle-select rather than strict
  press-and-hold. Pressing a chip selects it (glow + soft-slow); it stays
  selected past release until the player re-taps it, taps a room (seat
  attempt), or successfully seats it. This is friendlier for a "pressure,
  never stress" pillar and much easier to get right without live device
  testing than a hold-threshold gesture. Full drag-and-drop (Godot's
  built-in Control drag API) is also implemented in parallel and reaches
  the same `seat_guest` path, so both interaction styles work.

- **Housekeeping/checkout timing:** checkouts and the following
  housekeeping run at Morning start, which in this implementation is
  synonymous with the `{type="next_day"}` command's effect (there is no
  separate automatic transition into "morning" — only afternoon→evening,
  evening→night are automatic; morning is always entered via `next_day`).
  Day 1 has no prior night, so its schedule is generated directly in
  `SimGame._init()`, matching Part E's "Day 1 has no forecast... generate
  on the spot exactly once."

- **Ten-day soak's "queue empty at day end" invariant (Part F test 8):**
  not asserted as a hard failure. Tortoise's patience_mult (10x) gives it
  ~350 sim-seconds of patience against a ~100 sim-second day; on a static
  4-room starting hotel under sustained demand, a tortoise can legitimately
  still be queued across a day boundary. Part E only forces a walk at zero
  patience — nothing forces one at Night — so this is correct behavior,
  not a bug, and asserting it as a hard failure would make the test flaky
  against correct behavior rather than catch a real defect.

## Save/load

- Saving happens when the Night phase is entered (right after
  `day_summary_ready` fires), matching Part C's literal "written... at
  each Night phase." On launch, `game/main.gd` loads `user://save.json` if
  present, otherwise starts a fresh Day 1 — satisfying the Definition of
  Done's "relaunch resumes at the correct day/state."
