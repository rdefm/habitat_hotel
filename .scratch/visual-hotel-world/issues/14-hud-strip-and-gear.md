# 13 — The HUD strip and the gear

**What to build:** The hotel's vitals, always visible, calm. Four slots plus a gear: Cash, Hearts, a Star pill with Reputation rendered as its fill (Reputation being progress within a Star), and a day/season chip. Pause, 1x and 2x move behind the gear so the strip stays quiet.

The painted roofline carries a marquee sign; whether the Star rating lives there instead of in the strip is worth trying while building this, since the art already offers the slot.

The HUD stays a Control above the world and reads from `GameState` exactly as today.

**Blocked by:** 06

**Status:** ready-for-agent

- [ ] Cash, Hearts, a Star pill and a day/season chip are pinned at the top and update live
- [ ] Reputation renders as the Star pill's fill, not as a separate number
- [ ] Pause, 1x and 2x are reachable from the gear and control the clock as today
- [ ] The strip does not obscure the top of the building at fit-all framing
