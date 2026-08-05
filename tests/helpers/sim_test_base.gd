extends GutTest

## Shared setup for tests that drive the sim autoloads (GameState/Sim/Clock/
## Rng) through a full day/night cycle. Mirrors BatchRunner.run()'s reset
## sequence so every test starts from the same deterministic day-1 state,
## regardless of test order or what an earlier test left behind.
##
## Subclasses that override before_each() must call super.before_each()
## first to get this reset.

func before_each() -> void:
	Rng.reset()
	Clock.reset()
	GameState.reset_to_starting_conditions()
	Sim.reset()


func count_rooms(predicate: Callable) -> int:
	var count := 0
	for room in GameState.hotel_rooms:
		if predicate.call(room):
			count += 1
	return count


## A hand-built pending-arrival Party dict, for tests that drive
## Sim.seat_party()/Sim.match_hint() directly rather than depending on
## DemandGenerator's RNG-derived arrivals. Doesn't append it to
## Sim.pending_arrivals -- callers do that (or override fields first) since
## some tests want the party_size/nights_total tuned per case.
func make_party(id: int, needs: Array, party_size: int = 2, budget: String = "low", nights_total: int = 2) -> Dictionary:
	return {
		"id": id,
		"name": "Test Guest %d" % id,
		"species_id": "test_species",
		"needs": needs,
		"likes": [],
		"amenity_prefs": [],
		"budget": budget,
		"party_size": party_size,
		"nights_total": nights_total,
		"patience": float(GameState.balance["patience"]["start"]),
	}
