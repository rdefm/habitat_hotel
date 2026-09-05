# 02 — `manny` rename and the two-bay Room cap

**What to build:** Two mechanical data changes the world rebuild depends on, landed against the old view so they can be verified in isolation.

`marlon` becomes `manny` everywhere — a hard rename with no back-compat alias, as ADR-0018 specified, since Staffer ids are internal string keys and `SaveManager` is a stub that persists nothing. His existing walk and sweep art is the one real character asset in the project and the reference implementation the asset contract is validated against in ticket 06, so his id and his art should agree before that contract is written.

Every Room type's `max_instances` drops from 4 to 2, so the build rules agree with the two bays the background art draws per floor. The hotel's ceiling falls from 24 Rooms to 12. This is a real balance change accepted as-is — no compensating retune is in scope.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `marlon` appears nowhere in the codebase, data or tests; `manny` reads through the same code paths with no aliasing
- [ ] Every Room type in `data/rooms.json` has `max_instances` of 2
- [ ] Building a third instance of any Room type is refused by the same rule that refused a fifth before
- [ ] The Build Slot disappears from a Room type's row once two instances exist
- [ ] The whole suite is green, with only the mechanical rename and the instance-cap assertions touched
