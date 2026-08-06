class_name Station
extends RefCounted

## The four live service posts (ADR-0005) a Staffer can be assigned to.
## Distinct from a fixed Role: any Staffer can work any Station, and a
## Station holds a list of assigned Staffer ids rather than a single slot.
## Kitchen is tracked here like the other three but has no gated effect of
## its own yet -- that's wired to Dining in ticket 09.

const IDS := ["reception", "bellhop", "housekeeping", "kitchen"]


static func is_valid(station_id: String) -> bool:
	return IDS.has(station_id)
