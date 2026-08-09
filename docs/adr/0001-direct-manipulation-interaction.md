# Direct-manipulation interaction model, no auto-matcher

`hotel_habitat_plan.md` originally locked "menu-driven, no tappable world objects" with an auto-matcher that seats guests according to a Perfect-Fit-Only/Fill-Vacancies policy toggle. A working prototype (`habitat-hotel-prototype-4.html`) instead does everything by tapping the world directly: tap a Party then tap a Room to seat it (green/amber Match hinting), tap a Staffer then tap a Station to assign it, tap an empty Build Slot to construct.

We're keeping the prototype's model as the locked decision: seating, staffing, and building are always a deliberate tap-target/tap-destination action on the world itself. There is no auto-matcher and no Policy menu — seating every Party by hand *is* the core gameplay verb, so automating it away would remove the puzzle. Menus remain for non-spatial actions (Reports, Reviews, Prices, Save/Load).

Status: accepted, supersedes the interaction-model row of `hotel_habitat_plan.md` §1 and the Policy menu described in §13/GUIDE.md §10.
