# Bespoke modals augment the generic overlay, not replace it

Every menu (Prices, Hire, Roster, Terrace, Reports, Reviews, Build, Upgrade) currently shares one generic full-panel overlay (`ui/main_screen.gd`'s `open_menu()`/`close_menu()`). We're adding small, bespoke popups — matching the prototype's style — for four specific actions: seat-confirm, tapping an occupied Room for stay info, build-confirm, and tapping a Staffer for their detail card (skills/traits/current assignment, replacing the Roster menu's info-viewing role per ADR-0009). List/table-shaped menus (Prices, Hire, Reports, Reviews) stay on the generic overlay — they don't fit a small-popup shape.

Status: accepted.
