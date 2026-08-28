# 06 — Terrace floor reskin: Diner queue actors

**What to build:** Replace the Terrace's breakfast/dinner button-card list with Diner actors standing in a queue on the Terrace floor, matching Reception's guest-queue treatment (ticket 03) — including Patience-tier coloring for the dinner queue. Dragging a Staffer actor from the Staff Pool or another Station onto a specific Diner actor Stacks a Kitchen job on them via the existing Stacking mechanic, rejected the same way an invalid Stack is today. The Kitchen Station drop-zone itself (already on the Terrace per existing ADRs) is unaffected. Tapping the Terrace structure (not a Diner actor) keeps opening the existing Kitchen-staffing/Daily-Special/Upgrades modal, unchanged.

**Blocked by:** 02

**Status:** ready-for-agent

- [ ] Every breakfast-queue entry renders as a distinct actor on the Terrace floor
- [ ] Every dinner-queue entry renders as a distinct actor on the Terrace floor with the same Patience-tier coloring as today's list
- [ ] Dragging a Staffer actor onto a Diner actor currently being served Stacks a second Kitchen Staffer on that Job; dragging onto a Diner with no in-flight Job, or already at the Stack cap, is rejected with visible feedback
- [ ] The Kitchen Station drop-zone on the Terrace floor still accepts a dragged/tapped Staffer assignment exactly as today
- [ ] Tapping the Terrace structure itself still opens the existing Kitchen-staffing/Daily-Special/Upgrades modal, unchanged
