# 14 — Terrace/Dining UI

**What to build:** A Terrace view showing the breakfast queue, the walk-in dinner queue and each Diner's Patience state, a Daily Special picker, and the Terrace's own Upgrade menu (reusing the pattern from tickets 03/13). The dinner add-on indicator from ticket 12 is visible here as well as on the Room card.

**Blocked by:** 09, 10, 11, 12, 13

**Status:** done

- [x] The Terrace view shows the current breakfast queue state during Morning
- [x] The Terrace view shows the current walk-in dinner queue with visible Patience state during Evening
- [x] The player can choose tomorrow's Daily Special from this view
- [x] The Terrace's upgrade list is purchasable from this view
- [x] A room guest's dinner add-on is visible both here and on their Room card

## Comments

New `ui/terrace_menu.gd` (`TerraceMenu`, a `VBoxContainer`), opened as a modal from a new "Terrace" button in `main_screen.gd`'s menu bar, alongside Prices/Hire/Roster/Reports/Reviews. Four sections, top to bottom:

- **Breakfast Queue**: a read-over of `Sim.breakfast_queue` (ticket 09) -- one line per entry (`SpeciesName xN -- RoomName #instance`). Empty outside the window `_populate_breakfast_queue()` fills it (Morning through however long unserved entries persist), same as Reception's "No one waiting" empty state.
- **Walk-in Dinner Queue**: a read-over of `Sim.walkin_queue` (tickets 10/12) -- one line per entry with its Patience tier (calm/impatient/huffy, color-coded), and `" (Room add-on)"` appended whenever `guest_id != -1` -- i.e. a room guest's dinner add-on (ticket 12) rather than a true Walk-in Diner, the same distinction `hotel_panel.gd`'s `"+ Dinner"` Room-card tag already surfaces from the other side.
- **Daily Special**: an `OptionButton` (species list + "(none)") wired straight to `GameState.set_daily_special()`/`GameState.daily_special` (ticket 10 built where the choice lives; this is the picker). Note: the ticket text says "tomorrow's Daily Special," but the actual mechanic (ticket 10, `Sim._populate_walkin_queue()`, called from `_do_evening()`) biases *that same day's* Evening Walk-in Diners -- picking it any time before Evening starts is what actually takes effect, there's no separate "tomorrow" slot. Wired to the real mechanic rather than the ticket's wording.
- **Terrace Upgrades**: purchased/available upgrade rows, reusing `upgrade_menu.gd`'s row-building pattern (tickets 03/13) verbatim minus the room_type_id/instance_id addressing and the price row (the Terrace has no per-instance price) -- reads `GameState.effective_terrace_stats()`/`available_terrace_upgrades()`/`terrace_upgrades`, purchases via `GameState.purchase_terrace_upgrade()`.

Since opening any overlay menu pauses the Clock (`main_screen.open_menu()`), this view doesn't need its own `tick_advanced` refresh wiring the way `ReceptionPanel`/`HotelPanel` do -- nothing in `Sim` moves while it's open. `_refresh()` re-runs after every mutating action (buying an upgrade, changing the Daily Special) instead.

**`sim/patience_state.gd` generalized**: `PatienceState.tier()` took the whole `balance: Dictionary` and read `balance["patience"]` internally -- fine when Reception was its only caller, but the dinner queue decays against a different config (`dining.walkin_patience`, ticket 10) with its own `start`/`decay_per_tick`. Changed the signature to take the specific patience config dict directly (`tier(patience, patience_cfg)`); `reception_panel.gd`'s call site now passes `GameState.balance["patience"]` explicitly, and `tests/test_patience_state.gd` updated to match. `data/balance.json`'s `dining.walkin_patience` gained `impatient_at`/`huffy_at` (24/9), scaled proportionally to Reception's `patience.impatient_at`/`huffy_at` (40/15 against a `start` of 80 vs. dinner's `start` of 48 -- same ~50%/~19% fractions).

No new `CONTEXT.md`/ADR entries -- every term this ticket surfaces (Daily Special, Patience, Dining Party, Walk-in Diner, Terrace) was already defined by tickets 09-13.

Verification note: as in tickets 09-13, this environment's vendored `Godot_v4.4-stable_win64_console.exe` (4.4) still can't run the GUT suite (`config/features` requires 4.7 -- confirmed again this session, same `GutErrorTracker`/parse-error signature as before). UI Control-node scripts also can't be verified via a `--script`-mode smoke run the way `Sim`/`GameState` pure logic can: `--script` compiles the target (and anything it `preload()`s) before the project's autoload singletons are registered as global identifiers, so any script using bare `Sim`/`GameState`/etc. identifiers -- which is every `ui/*.gd` file in this codebase, `terrace_menu.gd` included -- fails to compile under that mode. (Confirmed this isn't specific to my code: `--check-only --script ui/upgrade_menu.gd`, an already-shipped file, fails identically.) Verified instead two ways: (1) a headless `--script` smoke run exercising every `GameState`/`Sim` query `terrace_menu.gd` consumes directly through the real autoloads (fetched via `root.get_node()`, not bare identifiers) -- confirmed the generalized `PatienceState.tier()` against both config shapes, seated a guest with a dinner add-on opted in, force-advanced through Morning/Midday/Evening, and confirmed `breakfast_queue` populated (1 entry), `walkin_queue` populated (2 entries, the add-on entry correctly `guest_id`-tagged), `GameState.set_daily_special()`/`daily_special` round-tripped, and `GameState.purchase_terrace_upgrade()` succeeded and updated `terrace_upgrades` -- exactly the data shapes `terrace_menu.gd`'s `_refresh_*()` methods read; and (2) a full headless boot of the real `main.tscn` (`--headless --quit-after 10`), which resolves autoloads normally and loads `main_screen.gd` (which now `preload()`s `terrace_menu.gd` for the new "Terrace" button) -- completed cleanly through Day 1 Morning with zero script errors attributable to this ticket's changes. Script deleted after verification, not committed.
