class_name Station
extends RefCounted

## The three live service posts (ADR-0005) a Staffer can be assigned to.
## Distinct from a fixed Role: any Staffer can work any Station, and a
## Station holds a list of assigned Staffer ids rather than a single slot.
## Kitchen gates the Terrace's breakfast service (ADR-0003, ticket 09) --
## see Sim._tick_breakfast().
##
## Bellhop was a fourth Station until ADR-0019 removed it along with its
## Escort Job; check-in is now a flat delay no Station gates at all (see
## Sim._start_checkin()). A Staffer with no Station -- the state Marlon
## starts in now -- is in the Staff Pool, which is the absence of an entry
## here rather than an id of its own.

const IDS := ["reception", "housekeeping", "kitchen"]

const LABELS := {
	"reception": "Reception",
	"housekeeping": "Housekeeping",
	"kitchen": "Kitchen",
}


static func is_valid(station_id: String) -> bool:
	return IDS.has(station_id)
