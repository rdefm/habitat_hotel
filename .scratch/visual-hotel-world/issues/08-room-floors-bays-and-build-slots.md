# 07 — Room floors: two bays, Build Slots, and Room state read from art

**What to build:** Each Room floor draws exactly two bays, and a bay's whole state is legible without opening anything.

A floor draws its built instances in bay order, then a Build Slot in the next bay if `GameState.can_build_more()` allows, then an empty shell. Tapping a Build Slot opens the existing build-confirm flow and constructs a Room there. A small door plate carries the Room number, derived from level and bay, so a toast or a review connects to the Room it came from.

Bay state comes entirely from art: dirtiness as a mess overlay driven by the Room's cleaning flag, and upgrades as props keyed to purchased upgrade ids. Tapping an occupied Room still opens the stay-info modal, so nothing is lost by moving to a visual view. Occupancy sprites and the Match hint glow arrive in later tickets; this ticket is the bay itself.

The layout model gains bay-to-Room-instance mapping — built instance, Build Slot, or empty shell — and the per-bay visual state derived from occupancy, cleaning and upgrade state.

**Blocked by:** 02, 05

**Status:** ready-for-agent

- [ ] Every Room floor shows exactly two bays
- [ ] A bay renders as a built Room, a Build Slot, or an empty shell according to what exists and what the build rules allow
- [ ] Tapping a Build Slot builds a Room there through the existing confirm flow, and the bay becomes a built Room
- [ ] A dirty Room shows visible mess after a checkout
- [ ] A purchased upgrade adds a visible prop to the Room interior
- [ ] Each built Room shows a door plate with its Room number
- [ ] Tapping an occupied Room opens the existing stay-info modal unchanged
- [ ] Bay mapping — including the Build Slot and empty-shell cases — and per-bay visual state are covered by tests against the pure layout model
