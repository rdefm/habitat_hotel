# Sitemap

Pithy map of what lives where. Use this to pick which files to open before
searching the whole tree. See `CONTEXT.md` for domain vocabulary and
`docs/adr/` for the "why" behind any of this.

## Runtime layers

**`autoload/`** — Godot singletons (global state/services), one concern each:
- `game_state.gd` — authoritative economy/session state + loaded data registries
- `clock.gd` — day/phase tick driver (pure timekeeping, no economy logic)
- `sim_controller.gd` — drives the guest lifecycle (arrive→queue→seat→stay→checkout) per phase
- `event_bus.gd` — global signal hub; sim emits, UI/world subscribe. No logic here.
- `rng_service.gd` — single source of randomness (determinism rule: never use Godot's global randi/randf)
- `save_manager.gd` — stub, not yet implemented

**`sim/`** — pure logic (`RefCounted`, no scene tree), the actual simulation rules:
- `data_loader.gd` — parses `res://data/*.json` into typed dicts, validates
- `building_layout.gd` — derives the floor stack from `rooms` catalog + stars (ADR-0020); also resolves art asset paths per the asset contract
- `demand_generator.gd` — generates each day's arriving parties (star/reputation/season gated)
- `match_hint.gd` — Party↔Room seating hint logic: green/amber/none (ADR-0001)
- `satisfaction.gd` — tag-match satisfaction scoring + review/Hearts thresholds
- `patience_state.gd` — Patience value → calm/impatient/huffy classification
- `station.gd` — the three Stations (Reception/Housekeeping/Kitchen) enum + rules (ADR-0005)
- `batch_runner.gd` — fast-forwards N days with no real-time wait, writes CSV (balancing tool)

**`ui/`** — Godot Control/Node2D views, one file per screen/menu/component. Naming tells you the shape:
- `main_screen.gd` (+`.tscn`) — top-level screen: HUD strip, the hotel world, toast layer, modal overlay, popup host
- `hotel_world.gd` — the Node2D building world (camera, portrait viewport) — the game's only play surface (ADR-0020, ticket 17 retired the older Control-based `hotel_view.gd`/`hotel_panel.gd` stack for good)
- `*_menu.gd` — full-panel modals opened via `main_screen.gd`'s overlay (e.g. `prices_menu`, `reports_menu`, `reviews_menu`, `reception_menu`, `terrace_menu`, `upgrade_menu`, `hire_menu` [stub])
- Bespoke small popups (ADR-0011), via `popup_host.gd`: `build_confirm_menu`, `seat_confirm_menu`, `stay_info_menu`, `staffer_detail_menu`
- `character_sprite.gd` — generic renderer for one resolved character/interface slot
- `*_actor.gd` — `hotel_world.gd`'s own world-space actor tokens (`staffer_actor`, `guest_actor`, `diner_actor`, `room_bay_actor`, `room_occupant_actor`)
- `needs_bubble.gd`, `idle_animator.gd` — small `hotel_world.gd` helpers (a lobby guest's Tag-icon Needs bubble; an actor's idle-clip animation)
- `toast_layer.gd` — the one surviving screen-space overlay: transient toasts anchored to a world position, projected through `hotel_world.gd`'s camera
- `demand_format.gd`, `pixel_theme.gd` — shared formatting/styling helpers

**`main.gd`** (+`main.tscn`) — entry point. Interactive mode boots `main_screen.tscn`; `--batch=N` runs headless via `sim/batch_runner.gd` and quits.

## Data

**`data/*.json`** — static content tables loaded once by `sim/data_loader.gd` into `GameState`: `species`, `rooms`, `staffers`, `traits`, `tags`, `terrace`, `seasons`, `names`, `balance`, `starting_hotel`.

**`assets/`** — art. `hotel_shell/` = building-shell slots per `docs/asset_contract.md`; loose files at root = character sprites (species, Manny).

## Tests

**`tests/`** — GUT (Godot Unit Test) specs, one file per feature/system, named `test_<thing>.gd`. `tests/helpers/sim_test_base.gd` is the shared base class. Run via the `addons/gut/` framework (third-party, don't edit).

## Docs & process (read before big changes)

- `CONTEXT.md` — domain glossary (canonical terms; "Avoid" lines flag deprecated synonyms)
- `docs/adr/NNNN-*.md` — architectural decisions, referenced by number throughout code comments and this sitemap
- `docs/asset_contract.md` — exact art slot/anchor spec for `ui/hotel_world.gd` + `sim/building_layout.gd`
- `docs/agents/domain.md`, `docs/agents/issue-tracker.md` — how agent skills should use the docs above and `.scratch/`
- `GUIDE.md` — player-facing "how to play" doc (design intent reference, not code)
- `hotel_habitat_plan.md` — the canonical original implementation plan (v1.0)
- `plans/vision-chunk-*.txt` — **non-canonical**, superseded (ADR-0006); mine for mechanic ideas only
- `.scratch/<feature-slug>/` — issue tracker: `spec.md` + numbered `issues/NN-*.md` per feature effort. `_COMPLETED` suffix = shipped; `visual-hotel-world/` (no suffix) = current in-flight effort

## Addons

**`addons/gut/`** — third-party GUT test framework. Don't edit; treat as vendored.

## Config

`project.godot` — Godot project settings (nearest-neighbour texture filtering is set here, relevant to any pixel-art asset work).
