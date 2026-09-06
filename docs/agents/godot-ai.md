# Visual verification: the godot-ai MCP plugin

`addons/godot_ai/` is a third-party editor plugin (vendored, don't edit) that exposes the running Godot editor and game to `mcp__godot-ai__*` tools. Use it to actually play the game and look at the result for any change to `ui/*.gd` — rendering, layout, camera, drag/tap hit-testing, animation. GUT (see `README.md`'s Testing section) only covers `sim/*.gd`'s pure logic; per `.scratch/visual-hotel-world/spec.md`'s Testing Decisions, everything node-tree/pixel/timing-shaped in `ui/` is explicitly "playtest-verified, not unit-tested" — godot-ai is how an agent does that playtesting instead of skipping it or just claiming success.

Run the headless GUT suite first, as normal. Reach for godot-ai only for the visual pass on top.

## Getting connected

Every `mcp__godot-ai__*` call fails with `PLUGIN_DISCONNECTED` until the **GUI editor** (not `--headless`) is open with this project loaded — the plugin is what bridges the editor to the MCP server, and headless mode never loads it. Use the same Godot 4.7 binary README.md's Testing section pins (not whatever `godot` resolves to on PATH — the version mismatch there applies here too), launched as:

```
<path-to-godot>\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe --editor --path .
```

Launch it backgrounded, then poll `editor_state` until it stops erroring — first response after launch is usually still `PLUGIN_DISCONNECTED` while the editor boots. No fixed wait works reliably; poll instead of sleeping a guessed duration.

## The verification loop

1. `project_run(mode="main")` — starts the game inside the editor.
2. Poll `editor_state` until `game_status.status == "live"`.
3. `editor_screenshot(source="game")` — a real screenshot of the running game (not the 3D editor viewport, which is `source="viewport"` and irrelevant to this 2D project).
4. `game_manage(op="get_ui_elements")` — the exact rect/global_rect/visibility of every live Control. Prefer this over eyeballing screenshot pixel coordinates for anything you're about to click, and over guessing why something looks wrong: it tells you the true resolved position/size, which a screenshot alone can hide (see the gotcha below).
5. `game_manage(op="input_mouse" / "input_key" / "input_action")` to actually drive taps/drags, and `editor_manage(op="game_eval")` to read or assert live `GameState`/`Sim`/`Clock` values directly rather than inferring them from pixels.
6. When done: `project_manage(op="stop")`, then `editor_manage(op="quit")`.

If you change a script while the game is running, stop and re-run rather than trusting hot-reload to have picked it up.

## A gotcha worth knowing before you hit it

A plain `Control` added directly under a `CanvasLayer` (not under another `Control`) can silently resolve to **zero width** even with `set_anchors_preset(Control.PRESET_TOP_WIDE)` or similar partial-stretch presets — the preset's own offset defaults don't reliably fill the viewport in that context. Its children can still look fine in a screenshot, because containers fall back to their own minimum size when their allocated rect is degenerate — so a screenshot alone can miss a zero-sized parent while `get_ui_elements` will show it immediately (`rect.size` near `{0, ...}`). Anything anchored *relative to* that phantom-zero-width Control (e.g. a popover anchored `PRESET_TOP_RIGHT` to it) then computes its position from the wrong reference frame and renders off-screen. Fix: after the preset call, set `offset_left`/`offset_right`/`offset_top`/`offset_bottom` explicitly rather than trusting the preset's snapshot-based defaults — `PRESET_FULL_RECT` (all four anchors stretched) doesn't have this problem, only partial-stretch presets do.
