## Before exploring the codebase

Read `sitemap.md` first to identify exactly which files are relevant to the change at hand, instead of searching the whole codebase.

## Agent skills

### Issue tracker

Local markdown under `.scratch/<feature-slug>/`. See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context — `CONTEXT.md` + `docs/adr/` at the repo root, created lazily as terms/decisions are resolved. See `docs/agents/domain.md`.

### Visual verification

For any `ui/*.gd` change (rendering, layout, camera, drag/tap), use the godot-ai MCP plugin to actually run the game and look — GUT doesn't cover this. See `docs/agents/godot-ai.md`.
