# 09 — Guests in the lobby: mood faces and Needs bubbles

**What to build:** Arriving Parties stand in the lobby as individual animal characters — a Party of three is three characters standing together, so party size is seen rather than read, and each is drawn from its Species' sprite slot (a placeholder until that art lands).

A mood face floats above every waiting guest at all times, souring continuously as Patience decays through content, impatient and huffy, so someone about to walk out is spottable from across the whole hotel rather than at a threshold crossing.

Tapping a waiting guest pops a bubble of Tag icons showing their Needs — the Match puzzle solved against icons, not a text card. Waiting diners on the Terrace use the same mood faces, so dining Patience reads the same way everywhere.

The layout model gains the lobby queue placement bucket and the mapping from a Patience value to a mood-face state.

**Blocked by:** 07, 09

**Status:** ready-for-agent

- [ ] An arriving Party stands in the lobby as one character per member, drawn from its Species slot
- [ ] Every waiting guest carries a mood face at all times, with no tap required
- [ ] The mood face sours continuously as Patience decays, through content, impatient and huffy
- [ ] Tapping a waiting guest pops a bubble of Tag icons for its Needs
- [ ] Waiting diners at the Terrace show the same mood faces as lobby guests
- [ ] Patience-to-mood mapping and lobby placement are covered by tests against the pure layout model
