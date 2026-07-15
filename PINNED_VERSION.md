# Pinned Godot Version

**Target: Godot 4.3 (stable)**

This project's GDScript targets the Godot 4.3 stable API surface (`@onready`,
`await`, `CharacterBody2D`, `Callable`-based signals, etc. — never Godot 3
syntax).

## Why this isn't a verified install

This chunk was implemented in a sandboxed remote session whose network policy
blocks github.com releases, downloads.tuxfamily.org (Godot's official host),
Flathub, and Snap. `apt` only offers Godot 3.5.2, which this project cannot
use. It was not possible to download and run an actual Godot 4.x binary in
this session, so `godot --headless --version` was never executed here, and
the headless test suite in `tests/` has not been run against a real engine.

**Action needed before trusting this build:** install Godot 4.3+ stable
locally (https://godotengine.org/download), confirm the exact version with
`godot --headless --version`, replace the line below with that exact string,
and run:

```
godot --headless --script res://tests/run_tests.gd
```

Report any failures — the code was written carefully against the 4.3 API
from documentation/training knowledge, but has zero engine-verified runs.

## Exact version string
`<UNVERIFIED — replace after first local run: e.g. "4.3.stable.official.xxxxxxxxx">`
