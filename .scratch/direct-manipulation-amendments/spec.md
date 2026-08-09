Status: ready-for-agent

# Direct-manipulation amendments: drag-and-drop, Station relocation, bespoke popups

## Problem Statement

ADR-0001 (tap-Party/tap-Room, tap-Staffer/tap-Station, no auto-matcher) shipped and is fully implemented (`.scratch/direct-manipulation-core-loop/`). Three later ADRs amend/extend it and remain unimplemented in the Godot build:

- **ADR-0009**: drag-and-drop as a second, coexisting gesture for Staffer→Station, Staffer→in-progress Job (Stacking, ADR-0008), and Party→Room. Reception/Bellhop/Housekeeping Station slots move out of the Roster menu into always-visible placement near Reception; Kitchen's slot moves onto the Terrace (ADR-0010). A Staffer's Skill/Trait detail becomes a tap-to-open popup (ADR-0011) instead of living in the Roster menu, which is retired as the place Station assignment happens.
- **ADR-0010**: the Terrace becomes an always-visible structure in the hotel view instead of a menu-bar entry. Tapping it opens a modal for Kitchen staffing, the Daily Special picker, and the Terrace Upgrades shop. The Daily Special and breakfast/dinner queues (with Patience) stay visible ambiently.
- **ADR-0011**: bespoke small popups (matching the prototype's style) augment the generic full-panel overlay for four specific actions: seat-confirm, tapping an occupied Room for stay info, build-confirm, and tapping a Staffer for their detail card. List/table-shaped menus (Prices, Hire, Reports, Reviews) stay on the generic overlay.

Verified against the current code: no drag-and-drop exists anywhere in `ui/`; `roster_menu.gd` still does Station assignment via tap-only inside the Roster menu; `terrace_menu.gd` still opens as a menu-bar item on the generic overlay; `seat_confirm_menu.gd` is explicitly opened via the generic overlay ("same as Build/Upgrade").

## Solution

Nine vertical slices, sequenced so the bespoke-popup host (ADR-0011) and the Station relocation (ADR-0009/0010) land first as the two independent prerequisites, then everything else layers on top:

1. Bespoke popup host + seat-confirm popup
2. Occupied-Room stay-info popup
3. Build-confirm popup
4. Reception/Bellhop/Housekeeping Station slots move out of the Roster menu
5. Terrace becomes always-visible; Kitchen's Station slot moves onto it
6. Staffer detail popup; Roster menu retired entirely
7. Drag-and-drop: Party → Room seating
8. Drag-and-drop: Staffer → Station assignment
9. Drag-and-drop: Staffer → in-progress Job (Stacking)

## Out of Scope

- GUIDE.md's stale §9/§10/§13/§14 (Policy, Staff, Hiring) — separate follow-up, not part of this batch.
- Staff training, traits, hire/fire pool (ADR-0002/0005 remainder) — untouched by this spec.

## Further Notes

ADR-0001, ADR-0008, ADR-0009, ADR-0010, and ADR-0011 in `docs/adr/` are authoritative; where a ticket below and an ADR disagree, the ADR wins.
