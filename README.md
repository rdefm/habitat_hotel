# habitat_hotel

## Testing

Sim logic is tested headlessly with [GUT](https://github.com/bitwes/Gut) (`addons/gut/`) against the project's autoloads (`GameState`, `Sim`, `Clock`, `Rng`, `EventBus`) — no manual scene setup or editor required. Tests live in `tests/`.

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
