# Drag-and-drop assignment; Stations leave the Roster menu

ADR-0001 locked tap-Party/tap-Room and tap-Staffer/tap-Station as *the* interaction model. We're adding drag-and-drop as a second, coexisting gesture for the same actions — Staffer→Station, Staffer→an in-progress Job (the Stacking gesture, ADR-0008), and Party→Room — both gestures always work side by side. This amends ADR-0001 rather than replacing it; the "no auto-matcher, every seating is deliberate" principle is unchanged.

Alongside this, Reception/Bellhop/Housekeeping Station slots move out of the Roster menu into always-visible placement near Reception (mirroring the prototype's layout), and Kitchen's slot moves onto the Terrace structure (ADR-0010). A Staffer's Skill/Trait detail becomes a tap-to-open popup (ADR-0011) instead of living in the Roster menu, which is retired as the place Station assignment happens.

Status: accepted, amends ADR-0001.
