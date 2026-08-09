# Species demand is no longer Star-gated

`hotel_habitat_plan.md` §2 and the shipped `DemandGenerator` filter arriving Species by `tier <= current Star`, so a Species never appears until its ideal Room type is even unlockable. We're removing that filter: any Species can arrive from day one, regardless of Star. Room-type unlocking is unaffected — `rooms.json`'s `unlock.star` still gates what's *buildable*; only Species *arrival* changes.

This was verified safe rather than assumed: `MatchHint.classify()` already returns `amber` for any tag mismatch regardless of how much overlap exists (it never hard-blocks on missing Needs alone), and the three starting Room types already share at least one Need-tag with every Species in `species.json`. So an out-of-tier Species arriving early always has somewhere to go — just not an ideal one. Species `tier` remains in `species.json` but is no longer read by `DemandGenerator`; repurposing it (rarity weighting, flavor) is open for a future ticket.

Status: accepted, supersedes the demand-queue row of `hotel_habitat_plan.md` §2 ("star level unlocks species tiers") and the Star definition in `CONTEXT.md`.
