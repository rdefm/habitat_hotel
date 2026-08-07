class_name Station
extends RefCounted

## The four live service posts (ADR-0005) a Staffer can be assigned to.
## Distinct from a fixed Role: any Staffer can work any Station, and a
## Station holds a list of assigned Staffer ids rather than a single slot.
## Kitchen gates the Terrace's breakfast service (ADR-0003, ticket 09) --
## see Sim._tick_breakfast().

const IDS := ["reception", "bellhop", "housekeeping", "kitchen"]


static func is_valid(station_id: String) -> bool:
	return IDS.has(station_id)
