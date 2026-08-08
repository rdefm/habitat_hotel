# 01 — Bespoke popup host + seat-confirm popup

**What to build:** A small, anchored popup component (matching the prototype's style) that stands apart from `main_screen.gd`'s generic full-panel overlay (`open_menu()`/`close_menu()`), and the first real user of it: the existing amber-match seat-confirm flow.

**Blocked by:** None — can start immediately

**Status:** done

- [x] A reusable small popup component exists, visually and structurally distinct from the generic full-panel overlay (no shared title bar / 640x440 panel chrome)
- [x] Opening the popup pauses the Clock and closing it resumes, same as the generic overlay's behavior
- [x] The amber seat-confirm flow (`ui/seat_confirm_menu.gd`) is shown via this new popup instead of `main_screen.open_menu()`
- [x] Confirm/cancel behavior, the missing-needs message, and `Sim.seat_party()` on confirm all work exactly as today
- [x] List/table-shaped menus (Prices, Hire, Reports, Reviews) are untouched and still use the generic overlay

## Comments

`ui/popup_host.gd` (`PopupHost`, `extends Control`) is the new component: a full-rect backdrop (`rgba(0,0,0,0.4)`, matching the prototype's `.modal-overlay`) behind a `CenterContainer`-ed `PanelContainer` styled via `StyleBoxFlat` (white, 12px corner radius, 16px padding — the prototype's `.modal-card`). No title bar or close button; content sizes the card itself (`seat_confirm_menu.gd` already sets its own `custom_minimum_size`). `open_popup(content)`/`close_popup()` mirror `main_screen.gd`'s `open_menu()`/`close_menu()` pause/resume-the-Clock behavior, but deliberately don't touch `_hotel_panel` — the host has no game-state knowledge, so callers own their own follow-up refresh, same as `main_screen.gd`'s existing `_finish_seating_flow()` already did on the confirm path.

`main_screen.gd` instantiates one `PopupHost` alongside the existing generic overlay in `_ready()`. `_on_seat_attempted()`'s amber branch now calls `_popup_host.open_popup(menu)` instead of `open_menu(...)`; its `resolved` callback closes the popup and refreshes the hotel panel on cancel (confirm's refresh comes for free via `_finish_seating_flow()`). `seat_confirm_menu.gd`'s own logic is untouched — only its header doc comment was updated to point at the new host.

No GUT-based test was added: this repo has no existing UI-level tests for `main_screen.gd` (it's pure UI wiring, characterized by its own class doc rather than tests, same as the other `ui/*_menu.gd` files), so this follows the established pattern. Verified via a full headless load of `main.tscn` (`godot --headless --path . --quit-after 2`) showing zero new script errors versus the pre-change baseline; GUT itself doesn't load in this sandbox's Godot 4.4 binary for reasons unrelated to this change (the `addons/gut` plugin scripts reference newer-Godot-only editor APIs), confirmed unchanged by reproducing the same failure on a clean stash of the working tree.
