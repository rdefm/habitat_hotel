# Traits become mechanically real, replacing the dormant set

`data/traits.json`'s five Traits (`snack_thief`, `crowd_pleaser`, `night_owl`, `shed_everywhere`, `early_riser`) have shipped as flavor text only — no sim code reads them. We're replacing that set wholesale with five Traits carrying real one-cost/one-benefit mechanics, adapted from vision-chunk-2's spec (ADR-0006) into this game's data shapes and balance.json conventions:

- **Chatterbox** — slower check-in, but a Reception Patience-decay aura bonus
- **Perfectionist** — cleans slower, but flags the Room so the next stay seated there gets a satisfaction bonus
- **Brisk** — faster check-in, small satisfaction penalty per check-in
- **Deep Sleeper** — reduced effectiveness in Morning, boosted in Evening
- **Quick Study** — gains XP faster (interacts with ADR-0012's Training)

This is a deliberate content replacement, not an extension of the current five — the old set is dropped rather than eventually wired up. A Staffer's Trait assignment needs a home in `data/staffers.json` (it currently has no `traits` field at all).

Status: accepted.
