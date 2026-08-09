# Terrace becomes an always-visible structure, not a menu

ADR-0003 fixed the Terrace as present from day one, "like Reception, not like a Room" — but the shipped UI still gates every Terrace interaction behind a menu button (`ui/terrace_menu.gd`). We're making the Terrace an always-visible structure in the hotel view instead: tapping it opens a modal for Kitchen staffing (its Station slot, per ADR-0009), the Daily Special picker, and the Terrace Upgrades shop. The current Daily Special and the breakfast/dinner queues (with Patience) stay visible ambiently without opening anything — mirroring how Reception's arrival queue is already always on screen.

Status: accepted, extends ADR-0003.
