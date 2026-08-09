# One Floor per Room type, not a free-form slot grid

The plan described a fixed grid of generic slots where the player chooses which Room type occupies each slot; slot position was purely cosmetic with no adjacency mechanics. The prototype instead gives every Room type its own dedicated Floor, capped at a fixed instance count (currently 4), where "building" always means "add another instance of this Floor's type" via a Build Slot at the end of its row.

We're keeping the prototype's Floor-per-type model. It reads cleanly as a building elevation, gives every Room type a stable, predictable home instead of a layout puzzle, and matches what's already built. The trade-off is that we give up the free-form layout puzzle and any future adjacency mechanics the grid model would have supported.

Status: accepted, supersedes the Slots model in `hotel_habitat_plan.md` §3.4.
