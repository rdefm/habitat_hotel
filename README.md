# habitat_hotel

## Testing

Sim logic is tested headlessly with [GUT](https://github.com/bitwes/Gut) (`addons/gut/`) against the project's autoloads (`GameState`, `Sim`, `Clock`, `Rng`, `EventBus`) — no manual scene setup or editor required. Tests live in `tests/`.

**Use Godot 4.7, not whatever `godot` resolves to on your PATH.** This project (`config/features` in `project.godot`) targets 4.7 specifically. A `godot.exe` installed via WinGet or similar package managers commonly resolves to a 4.4.x build instead — that's a hard incompatibility, not just a version-string mismatch: GUT's `error_tracker.gd` extends the engine's built-in `Logger` class (`OS.add_logger()`), which doesn't exist anywhere in the 4.4.x line, only from 4.7 on. Running the test command below against a 4.4.x binary fails to resolve `GutErrorTracker` and hangs indefinitely rather than erroring out cleanly, so it's easy to mistake for a stuck import rather than a wrong-engine problem. Point the commands below at an actual `Godot_v4.7-stable_win64_console.exe`, not a generic `godot` shim.

Run the full suite from the repo root:

```powershell
& "<path-to-godot>\Godot_v4.7-stable_win64_console.exe" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

On first run against a fresh checkout (or after adding new addon scripts), Godot needs to import the project once before GUT's class_names resolve:

```powershell
& "<path-to-godot>\Godot_v4.7-stable_win64_console.exe" --headless --path . --import
```

`.gutconfig.json` pins the default test directory and exit-on-completion behavior, so `-gdir`/`-gexit` above are redundant but kept explicit for copy-paste use elsewhere (e.g. CI).

Tests that need a clean day-1 game state extend `tests/helpers/sim_test_base.gd`, which resets `Rng`/`Clock`/`GameState`/`Sim` in `before_each()` (mirroring `BatchRunner.run()`'s reset sequence) so every test starts from the same deterministic state regardless of run order.
