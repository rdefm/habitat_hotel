# 05 — Terrace becomes an always-visible structure; Kitchen's Station slot moves onto it

**What to build:** The Terrace becomes a tappable structure in the main hotel view (like Reception), replacing the "Terrace" menu-bar entry. Tapping it opens a modal for Kitchen staffing, the Daily Special picker, and the Terrace Upgrades shop; the Daily Special and breakfast/dinner queues (with Patience) stay visible ambiently without opening anything.

**Blocked by:** 04 (reuses the Station-slot widget built there for Kitchen's slot)

**Status:** ready-for-agent

- [ ] The Terrace is rendered as an always-visible, tappable structure in the main hotel view
- [ ] Tapping the Terrace opens a modal containing: Kitchen Station staffing (assign/reassign via the same tap-Staffer/tap-Station gesture as ticket 04), the Daily Special picker, and the Terrace Upgrades shop
- [ ] The current Daily Special and the breakfast/dinner queues, each entry showing its Patience tier, are visible in the main view without opening the modal
- [ ] The "Terrace" menu-bar entry is removed; `terrace_menu.gd`'s content is reorganized into the ambient view + modal split described above
- [ ] Kitchen Station assignment no longer lives in `roster_menu.gd`
