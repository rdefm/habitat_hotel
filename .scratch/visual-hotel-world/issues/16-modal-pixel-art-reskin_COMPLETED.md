# 15 — Modal pixel-art reskin

**What to build:** Opening a modal should not feel like leaving the game. Every surviving modal — seat-confirm, build-confirm, stay-info, staffer-detail, upgrade, terrace, and the reception admin tabs (prices, hire, reports, reviews) — is reskinned with a pixel-art theme sharing the world's palette and font.

Content and every `Sim`/`GameState` call stay exactly as they are. Moving any modal into the world is explicitly out of scope; the review pass that justifies or removes each one is later, separate work.

**Blocked by:** 04

**Status:** done

- [x] Every listed modal uses the shared pixel-art theme, palette and font
- [x] No modal's content, controls or Sim/GameState calls change
- [x] A modal opened over the world reads as part of the same game, not a different one

## Comments

Implemented as `ui/pixel_theme.gd`, a static `Theme` builder sharing the world's dark/gold palette (`ui/hud_strip.gd`'s backing/gear-popover/Reputation-fill colors) and the engine's default font (no pixel bitmap font asset exists yet, so "sharing the world's font" means not introducing a second one). `PixelTheme.themed_panel()` is called once each at the two modal host roots — `ui/popup_host.gd`'s `_card` (the bespoke small popups: seat-confirm, build-confirm, stay-info, staffer-detail) and `ui/main_screen.gd`'s generic overlay panel (upgrade, terrace, and the reception admin tabs via `reception_menu.gd`'s `TabContainer`) — and Godot's ordinary theme-propagates-down-the-tree behavior does the rest. None of the 11 individual modal `.gd` files were touched: every Button/Label/TabContainer/OptionButton they build at runtime inherits the theme automatically, so content, controls and every `Sim`/`GameState` call are untouched, per spec.

Visually verified live via the godot-ai MCP plugin: build-confirm popup, the reception overlay with its Prices tab, a staffer-detail popup layered on top of the terrace overlay (confirming stacking + TabContainer + OptionButton styling), all reading as one consistent dark/gold pixel-art chrome against the world. `/code-review` (standards + spec, run in parallel) came back clean — no hard violations, no missing/partial requirements, no scope creep; one minor duplicated-code smell (the theme-plus-stylebox wiring repeated at both host call sites) was fixed by extracting `PixelTheme.themed_panel()`.
