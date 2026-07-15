# Playtesting Habitat Hotel (Chunk 1 / M1: "The Afternoon")

## The question this build exists to answer

**Is seating guests fun for ten consecutive in-game days, with nothing
else in the game?**

Everything in this chunk serves that question. There is no meta-progression,
no staff, no reviews, no Trumpet forecast — just checkouts, a cleaning race,
an arrival queue, and dragging guests into rooms, ten days running.

## Before you start: verify the engine

This chunk was implemented in a sandboxed session with no network access to
github.com/tuxfamily.org/Flathub/Snap, so **no Godot binary was ever run
against this code.** Before trusting anything below:

1. Install Godot **4.3 stable or newer** (https://godotengine.org/download).
2. `godot --headless --version` and paste the exact string into
   `PINNED_VERSION.md`.
3. Run the test suite (below) and fix forward from whatever it reports.

## Running the game

Open `project.godot` in the Godot editor and run (F5), or headless-launch:

```
godot --path . 
```

The main scene is `res://game/main.tscn`. Portrait viewport (540x960),
placeholder programmer-art throughout (`game/stubs/sprite_factory.gd` is the
only file that draws anything — swap it out later for real art).

**Controls:** tap a guest chip in the queue strip to select it (rooms glow
gold/amber on the grid, sim soft-slows); tap a glowing room to seat, or drag
the chip onto a room directly. Dropping/tapping an amber room shows a
one-line confirm before seating. Tap an empty plot to open the build menu.
HUD top bar has Pause / 1x / 2x. Night phase shows the day summary
automatically; "Open tomorrow" advances the day.

## Running the tests

```
godot --headless --script res://tests/run_tests.gd
```

Exit code 0 and `All tests passed.` on success. Each of the 8 required
suites (Part F) prints `[PASS]`/`[FAIL]` with readable failure messages. If
you change `data/balance.json`, re-run this — tests 5-8 are the balance
instruments and should keep passing (or tell you precisely why a change
broke pacing).

## What to watch for while playing

1. **Is the queue too easy or too frantic?** A full arrival queue should be
   comfortably clearable by an attentive player at 1x. If you're never
   worried, or you're constantly losing guests to impatience even when
   paying full attention, `balance.json`'s `base_patience_sim_seconds` and
   `arrivals_ramp_by_day` are the levers — no code changes needed.

2. **Do ambers feel like choices, not just misses?** The interesting
   moment is deciding between an available amber room now vs. waiting on a
   room mid-clean that would be gold. If ambers just feel like "the game
   punished me," `amber_missing_need_satisfaction_penalty` may be too harsh,
   or room tag overlap may need adjusting in `data/rooms.json`.

3. **Do mornings feel idle?** Housekeeping should be a visible race, not
   dead air — watch whether the cleaning-progress sliver and the "fresh
   flash" on `clean_finished` actually read as tension building toward the
   afternoon rush, or whether morning is just a pause before the real game.

4. **Does splitting a big party feel like a real decision?** Try
   deliberately seating a party across two rooms, and separately, try
   letting a remainder walk instead. Both should feel like legitimate
   choices with a visible, understandable cost (Part A/E) — not a hidden
   penalty or a strictly-dominant option every time.

## Known gaps to expect on first run

- No sound, no real art, no tutorial (all correctly out of scope — Part H).
- The build menu, amber-confirm dialog, and night summary are functional
  but visually plain (`Button`/`Label`/`StyleBoxFlat` only).
- This is the first engine-verified run of this codebase. Expect at least
  minor breakage; report failures back so they can be fixed forward.
