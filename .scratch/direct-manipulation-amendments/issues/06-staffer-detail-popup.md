# 06 — Staffer tap opens a bespoke detail popup; Roster menu retired

**What to build:** Tapping any Staffer, at their Reception-area or Terrace placement, opens a bespoke popup with their per-Station Skill, Traits, and current assignment. With both of the Roster menu's former jobs (assignment, info) now living elsewhere, the Roster menu is deleted entirely.

**Blocked by:** 01 (Bespoke popup host), 04 (Reception-area Staffer placement), 05 (Terrace/Kitchen Staffer placement)

**Status:** ready-for-agent

- [ ] Tapping any Staffer (at Reception-area Stations or the Terrace's Kitchen slot) opens a bespoke popup showing their Skill rating at each of the four Stations, their Traits, and their current assignment
- [ ] The popup uses the popup host from ticket 01
- [ ] The "Roster" menu-bar entry and `roster_menu.gd` are removed entirely
- [ ] Every Staffer previously visible in the Roster menu remains reachable and tappable from their new Station placement — no Staffer becomes inspectable-only-via-code
