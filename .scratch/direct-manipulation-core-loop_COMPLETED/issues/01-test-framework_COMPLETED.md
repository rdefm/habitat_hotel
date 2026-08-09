# 01 — Stand up headless test framework and characterization tests

**What to build:** A working headless test framework wired to the project's autoloads so `GameState`/`SimController` can be exercised without the Godot scene tree beyond what autoloads require, plus a baseline set of characterization tests that pin down today's build/seat/checkout behavior (auto-matcher policies, flat slot addressing) so later rewrites in this effort have a regression net to work against before that behavior is replaced.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] A test runner executes headlessly (CI/CLI) against the sim autoloads with no manual scene setup
- [x] Characterization tests cover: building a room into an unlocked slot, both existing Matcher policies admitting/turning away a guest, a full day/night cycle producing a day summary, and a checkout producing a review
- [x] Test run instructions are discoverable (e.g., a documented command) for every ticket after this one to reuse

## Comments

Implemented via GUT (`addons/gut/`), vendored from github.com/bitwes/Gut v9.6.1. Enabled as an editor plugin in `project.godot`. Tests live in `tests/`:

- `tests/test_smoke.gd` — autoloads/data are reachable headlessly
- `tests/test_build_room.gd` — `GameState.build_room()` into the current flat slot grid (unlocked/locked/occupied/un-unlocked-type/insufficient-cash)
- `tests/test_matcher_policies.gd` — `Matcher.decide()` under both `strict_match` and `fill_vacancies`, called directly as a pure function
- `tests/test_day_night_cycle.gd` — one `Clock.force_advance_day()` producing a pinned day-1 summary
- `tests/test_checkout_review.gd` — checkout producing a posted review, pinned to the deterministic seed-1337 sequence; also documents a real quirk (day N+1's Morning/checkout processing runs inside the `force_advance_day()` call that finishes day N, one call before that day's own summary is emitted)

`tests/helpers/sim_test_base.gd` is a shared `before_each()` (Rng/Clock/GameState/Sim reset, mirroring `BatchRunner.run()`) other test files extend for a clean deterministic day-1 state.

Run command documented in `README.md` under "Testing": `godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit` (needs a one-time `--headless --import` on a fresh checkout so GUT's class_names resolve). `.gutconfig.json` pins the same defaults so the bare `-s addons/gut/gut_cmdln.gd` invocation also works.

18/18 tests passing, verified deterministic across repeat runs.
