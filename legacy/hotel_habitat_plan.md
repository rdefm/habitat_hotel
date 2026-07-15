# GRAND SAFARI HOTEL (working title)
## Implementation Plan — v1.0
A Kairosoft-style animal hotel management sim. Premium one-price mobile game. Built in Godot 4 with GDScript, coded via Claude Code, chunk by chunk.

---

## 1. Locked Design Decisions

| Decision | Choice |
|---|---|
| Engine | Godot 4.x, GDScript, text-based scenes (.tscn) |
| Business model | Premium, one price, no IAP/ads |
| Game arc | Finite (reach 5★ within time limit → scored ending), then optional endless sandbox |
| Day length | 60 real seconds per in-game day (tunable constant) |
| Hotel layout | Fixed slots, unlocked by star level / expansion purchases |
| Habitat system | Needs-based tags: rooms have 2–3 tags, species need specific tag sets |
| Interaction model | Menu-driven. Sim runs while menus are open. Modal decisions auto-pause. No tappable world objects. |
| Failure | Soft failure only: debt forces painful choices, never game over. Stars are a ratchet (never lost); a Reputation meter within the current star swings both ways. |
| Staff | Named individuals: species + traits. A few authored starters, rest procedurally generated. |
| Meta-currency | Hearts (from happy checkouts) spent on training, blueprints, species unlocks |
| v1 content scope | 8 guest species, 6 room types, 4 staff roles, 4 amenities, 2 seasons |
| Art | Placeholder/asset-pack until the sim is proven fun (Fun Gate after Chunk 2) |

---

## 2. Core Loop (one 60-second day)

The day is divided into phases driven by a tick system (e.g. 1 tick = 0.25s, 240 ticks/day):

1. **Morning (0–15s):** Checkouts resolve → cash, review, and Hearts awarded per guest based on stay satisfaction. New arrivals drawn from the demand queue.
2. **Midday (15–40s):** Guests matched to rooms (auto-match with player-set policy). Guests use amenities. Staff perform service tasks; staff traits and training modify service quality.
3. **Evening (40–55s):** Meals, incidents may fire, satisfaction accumulates.
4. **Night (55–60s):** Day summary written to log. Queued decisions (if any) present as modals. Wages/costs deducted daily; end-of-week (7 days) shows a report.

**Player interaction:** at any time, open menus to Build, Hire, Train, Set Prices, view Reports, or respond to queued Offers (e.g. flamingo wedding). Time controls: pause / play / 2x fast-forward. Modal decisions force pause.

**Demand queue:** each day, N prospective guests are generated based on: star level (unlocks species tiers), reputation (quality/quantity of guests), season (biases tags in demand), and active events. A guest whose needs can't be met either takes a mismatched room (satisfaction penalty) or walks away (small reputation hit) depending on vacancy and player policy.

---

## 3. Data Model (data-driven from day one)

All content lives in JSON (or Godot custom Resources) under `res://data/`. The sim reads these; adding a species or room type must require zero code changes.

### 3.1 Tags (the habitat vocabulary)
v1 tag set (8): `cold`, `warm`, `water`, `dry`, `high_perch`, `spacious`, `dark`, `quiet`

### 3.2 Species (guests)
```json
{
  "id": "penguin",
  "name": "Penguin",
  "tier": 2,
  "needs": ["cold", "water"],
  "likes": ["quiet"],
  "budget": "mid",
  "party_size": [1, 4],
  "base_stay_days": [1, 3],
  "amenity_prefs": ["pool"],
  "flavor_lines": ["Waddled all the way here.", "The ice machine better be REAL ice."]
}
```
- **needs** must all be present in the assigned room for a "matched" stay; missing needs give stacking satisfaction penalties.
- **likes** are bonus tags (small satisfaction boost, never required).
- **tier** gates which star level the species appears at.

**v1 species roster (suggested — tune freely):**

| Species | Tier (★) | Needs | Likes |
|---|---|---|---|
| Pigeon | 1 | high_perch | — |
| Capybara | 1 | warm, water | quiet |
| Tortoise | 1 | warm, dry | quiet |
| Penguin | 2 | cold, water | quiet |
| Flamingo | 2 | warm, water | spacious |
| Bat | 3 | dark, high_perch | quiet |
| Polar Bear | 3 | cold, spacious | water |
| Snow Leopard | 4 | cold, high_perch, quiet | spacious |

Note the deliberate overlaps: one `warm+water` room serves capybaras AND flamingos; a `cold+water` room serves penguins and pleases polar bears. This is the puzzle.

### 3.3 Rooms
```json
{
  "id": "ice_grotto",
  "name": "Ice Grotto",
  "tags": ["cold", "water"],
  "build_cost": 3000,
  "upkeep_per_day": 40,
  "base_rate": 120,
  "capacity": 4,
  "unlock": {"star": 2},
  "upgrades": [
    {"id": "soundproofing", "adds_tag": "quiet", "cost_hearts": 15, "cost_cash": 800}
  ]
}
```
**v1 room types (suggested):** Cozy Nook (`warm, quiet`), Roost Loft (`high_perch, dry`), Lagoon Room (`warm, water`), Ice Grotto (`cold, water`), Cavern Suite (`dark, quiet, high_perch`), Tundra Hall (`cold, spacious`). Upgrades add a third/fourth tag — this is how one room type stretches across species and stays relevant.

### 3.4 Slots
The hotel is a fixed grid of slots (e.g. 3 floors × 6 slots at start, expandable to 5 × 8). Each slot holds one room or amenity. Some slots are locked behind star level or an expansion purchase. Slot position matters only for the visual layer (v1); no adjacency mechanics (leave a hook for later).

### 3.5 Staff
```json
{
  "id": "generated_uuid",
  "name": "Marcel",
  "species": "monkey",
  "role": "bellhop",
  "level": 1,
  "stats": {"speed": 6, "charm": 4, "diligence": 3},
  "traits": ["snack_thief", "crowd_pleaser"],
  "wage_per_day": 30,
  "authored": true
}
```
- **Roles (4):** Receptionist (check-in speed/quality), Bellhop (arrival service), Housekeeper (room condition decay counter), Chef (meal quality → big satisfaction lever).
- **Traits** are data-defined modifiers with hooks: e.g. `snack_thief` (−small cash daily, +charm), `night_owl` (+performance in evening phase), `shed_everywhere` (housekeeping load +10%). Aim for ~15 traits at launch; they're the humor delivery system.
- **Training:** spend Hearts + cash → level up a stat; short cooldown (staff unavailable 1 day, "at seminar").
- **Authored starters:** 3 hand-written characters with fixed names/traits so the opening has personality; hire pool thereafter is generated, refreshing weekly, quality scaling with star level.

### 3.6 Amenities
Pool (`water` species boost), Restaurant (enables meal satisfaction, required for 2★), Sauna (warm/cold interplay jokes), Perch Garden. Each occupies a slot, has upkeep, and boosts satisfaction for guests whose prefs match.

### 3.7 Economy state
`cash`, `hearts`, `reputation` (0–100 within current star), `stars` (1–5), `day`, `season`, plus review counters.

---

## 4. Progression Spine

### Star milestones (ratchet — never lost)
Each star requires **reviews AND checklist**, e.g.:

| To reach | Positive reviews | Checklist |
|---|---|---|
| 2★ | 50 | Restaurant built, 2 staff at level 2, cash ≥ 0 |
| 3★ | 150 | 6+ rooms, 1 room fully upgraded, hosted 1 special event |
| 4★ | 350 | All 4 roles staffed at level 3+, reputation ≥ 70, expansion purchased |
| 5★ | 700 | Host a Tier-4 guest with perfect stay, all amenities, reputation ≥ 85 |

Each star unlocks: next species tier, new room/amenity blueprints, better weekly hire pool, more slots, higher price ceilings.

### Reputation (the daily swing)
0–100 meter within the current star. Rises with good reviews, falls with bad ones, walk-aways, and incidents. Affects daily demand volume and guest quality. Cannot demote a star, but low reputation makes the next star painfully slow — the loss-aversion lever.

### Finite arc & endless mode
Target: reach 5★ within **8 in-game years** (2 seasons × 30 days × … — tune; roughly 480 days ≈ 8 hours of play). At the deadline or on hitting 5★: scored ending ceremony (score = stars, cash, reputation, guest species collection, staff levels, review totals) with rank titles (e.g. "Roadside Burrow" → "Legendary Grand Safari"). Then offer **Endless Mode**: same save continues, milestones become score chases, rare "mythic" guests (e.g. Okapi, Axolotl King) appear as endgame collection content.

### Soft failure
Cash can go negative. At −2000: forced modal offering painful choices (sell a room at 50% value, take a predatory loan from the Vulture Bank with daily interest, or fire staff). Never game over; the Vulture Bank is a humor + tension device.

---

## 5. Build Chunks

Each chunk is a self-contained Claude Code work order: goal, deliverables, acceptance test. Do not start chunk N+1 until N's acceptance passes. Keep the sim strictly separated from presentation throughout (sim emits signals; UI/world views subscribe).

### Chunk 0 — Project skeleton (½ day)
- Godot 4 project; folders: `res://sim/`, `res://data/`, `res://ui/`, `res://world/`, `res://autoload/`.
- Autoload singletons: `GameState`, `EventBus` (signal hub), `SaveManager` (stub), `Clock` (tick/phase driver with pause/1x/2x).
- Data loaders that parse `data/*.json` into typed dictionaries; validation with clear error output.
- **Accept:** project runs, loads all data files, prints roster of species/rooms/traits, clock ticks through day phases in console.

### Chunk 1 — Headless simulation core (the real game)
- Demand generator (star/reputation/season weighted), guest lifecycle state machine (arrive → match → stay → use amenities → checkout), tag-matching satisfaction scoring, review generation, cash/Hearts accounting, daily costs.
- Auto-matcher with a simple policy setting (strict match only vs. fill vacancies).
- Deterministic RNG with seed (critical for testing/balancing).
- Debug console: text summary each day; a headless batch mode that simulates N days and dumps CSV of economy metrics.
- **Accept:** batch-run 60 days from starting conditions; economy is survivable but tight (ends between −500 and +3000 cash on default policy); satisfaction distribution sane; no guest stuck in a state.

### Chunk 2 — Menu UI layer ("spreadsheet game")
- Main screen: placeholder hotel panel + top bar (cash, Hearts, reputation, stars, date, time controls).
- Menus: Build (slot grid, room catalog), Hire (weekly pool), Staff (train/fire), Prices, Reports (daily log, weekly report), Reviews feed.
- Modal decision queue (auto-pause). Day log ticker.
- Godot UI theme kept minimal; no art yet.
- **Accept: THE FUN GATE.** A human plays 30 minutes making real decisions. If the choose-what-to-build-for-the-demand-you-see loop isn't engaging here, fix the sim before proceeding. Do not pass this gate on hope.

### Chunk 3 — Progression spine
- Star milestone system (reviews + checklist), unlock tables applied to demand/catalogs/hire pool, reputation meter effects, soft-failure debt modals, Vulture Bank.
- Finite arc: calendar, ending trigger, scoring ceremony screen, endless-mode handoff.
- **Accept:** scripted fast-forward run reaches 3★ legitimately; debt path triggers correctly; ending fires at deadline with correct score.

### Chunk 4 — Staff as characters
- Trait system with modifier hooks into sim events; procedural staff generator (name banks per species, stat budgets by star level); 3 authored starters; training flow with cooldown; weekly hire pool refresh.
- Staff detail screen with portrait placeholder, stats, traits, flavor bio.
- **Accept:** traits measurably change batch-sim outcomes (CSV diff with/without); hire pool quality scales with stars; training costs feel meaningful at Chunk-2 economy tuning.

### Chunk 5 — Seasons, events, incidents (the anti-solve layer)
- 2 seasons (Summer/Winter) rotating demand tag weights (winter: cold-species surge).
- Offer events as queued modals: tour groups ("12 pigeons, one night, loud"), VIPs, the flamingo wedding (multi-room booking with big review payoff/risk).
- Incidents: skunk in the pool, capybara refuses to leave hot tub, bat complains about breakfast hours. Mostly flavor+small effects; a few need a modal choice.
- Content: ~10 offers, ~15 incidents, all data-defined.
- **Accept:** 60-day batch shows demand composition shifting by season; offers accept/decline paths both resolve; incident frequency tuned (~1 per 2–3 days).

### Chunk 6 — Hotel world view (read-only)
- Side-on cutaway of the slot grid; rooms render by type; simple agents (colored capsules/asset-pack sprites) pathing: guest walks to reception → bellhop escorts to room → pool visits → checkout walk.
- Purely a visualization of sim signals; zero gameplay logic. Speech-bubble emotes (♥, 💢) mirroring satisfaction events.
- **Accept:** watching one full day is legible and mildly entertaining with placeholder art; sim results identical with view on/off (determinism check).

### Chunk 7 — Juice & content pass
- Integrate pixel art asset packs (recommend itch.io packs, e.g. LimeZu-style interiors + animal sprite packs; commission originals only after fun is proven); UI reskin; SFX + light music; review popups with species flavor lines; humor writing pass across all flavor text; day-summary polish; ending ceremony presentation.
- **Accept:** 10-minute "first play" feels charming to a fresh tester; every species/trait/incident has at least one joke.

### Chunk 8 — Mobile ship prep
- Touch UX (min 44px targets, bottom-reachable menus), save/load (autosave each night phase, 3 slots), settings, performance pass (target 60fps mid-tier Android), tutorial as guided first 3 days, iOS/Android export pipelines, store metadata.
- **Accept:** clean install → 3-year playthrough on a real device with no crash/save loss; battery and thermal acceptable.

---

## 6. Working With Claude Code

- One chunk per work order; paste the relevant plan section as the spec. Keep a `DESIGN.md` in-repo mirroring this document as source of truth.
- Demand tests: sim logic gets GUT (Godot Unit Test) coverage, especially matching, economy, and progression triggers. Batch/CSV mode is the balancing tool — tune numbers in data files, never in code.
- Enforce the sim/presentation split in review: any UI file importing sim internals directly (rather than via EventBus/GameState API) is a defect.
- Determinism rule: all randomness through the seeded RNG service. This makes bugs reproducible and lets Claude Code verify changes via before/after batch runs.

## 7. Key Tunables (initial values)

Starting cash 5,000 · starting slots 3×6 (4 unlocked) · starting staff: 2 authored + hire pool of 3 · day = 60s = 240 ticks · demand 2–5 guests/day at 1★ · Hearts per happy checkout 1–3 (satisfaction-scaled) · room build costs 800–8,000 by tier · wage range 20–120/day · season length 30 days · finite arc 480 days.

## 8. Risks & Mitigations

- **Biggest risk: the loop solves itself** (build every room type, done). Mitigations already in-plan: overlapping tag needs, seasonal demand rotation, limited slots forcing tradeoffs, upgrade-vs-build decisions, offers that reward spare capacity. Validate at the Fun Gate.
- **Scope creep in the world view.** It is read-only and last-but-two for a reason. Any proposal to make it interactive gets parked for a sequel/update.
- **Balancing time is real time.** The CSV batch mode exists so tuning is minutes, not hours of replaying.
- **Art dependency.** Fun Gate before any art spend; asset packs chosen for consistent 16×16 or 32×32 grid to keep swap-out cheap.
