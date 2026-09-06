extends GutTest

## Characterizes ticket 10's lobby-guest extension of
## sim/building_layout.gd: lobby_guest_placements() (one queue slot per
## Party MEMBER, not per Party) and resolve_lobby_guest_point(). Same shape
## as tests/test_terrace_diner_placement.gd -- literal hand-built
## pending_arrivals dicts, no autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


func _rooms() -> Dictionary:
	var out := {}
	out["cozy_nook"] = {"name": "Cozy Nook", "unlock": {"star": 1}}
	return out


func _floors() -> Array:
	return BuildingLayout.floors(_rooms(), 1)


func _party(id: int, party_size: int) -> Dictionary:
	return {"id": id, "name": "Party %d" % id, "species_id": "test_species", "party_size": party_size, "needs": [], "patience": 80.0}


## --- lobby_guest_placements() ---

func test_a_single_member_party_gets_one_queue_slot() -> void:
	var placements := BuildingLayout.lobby_guest_placements([_party(1, 1)])

	assert_eq(placements.size(), 1)
	assert_eq(placements[0], {"party_id": 1, "member_index": 0, "queue_index": 0})


func test_a_party_of_three_gets_three_consecutive_queue_slots() -> void:
	var placements := BuildingLayout.lobby_guest_placements([_party(1, 3)])

	assert_eq(placements.size(), 3, "party size should be seen as three standing characters, not read off a caption")
	assert_eq(placements[0], {"party_id": 1, "member_index": 0, "queue_index": 0})
	assert_eq(placements[1], {"party_id": 1, "member_index": 1, "queue_index": 1})
	assert_eq(placements[2], {"party_id": 1, "member_index": 2, "queue_index": 2})


func test_a_second_partys_members_continue_the_queue_after_the_firsts() -> void:
	var placements := BuildingLayout.lobby_guest_placements([_party(1, 2), _party(2, 1)])

	assert_eq(placements[0]["queue_index"], 0)
	assert_eq(placements[1]["queue_index"], 1)
	assert_eq(placements[2], {"party_id": 2, "member_index": 0, "queue_index": 2})


func test_no_pending_arrivals_yields_no_placements() -> void:
	var placements := BuildingLayout.lobby_guest_placements([])

	assert_eq(placements, [])


## --- resolve_lobby_guest_point() ---

func test_resolve_lobby_guest_point_matches_the_lobby_queue_anchor_at_the_same_index() -> void:
	var floors := _floors()
	var queue_point := BuildingLayout.resolve_lobby_queue_point(floors, BuildingLayout.GROUND_FLOOR_LEVEL, 1)

	var point := BuildingLayout.resolve_lobby_guest_point(floors, 1)

	assert_eq(point, queue_point)


func test_resolve_lobby_guest_point_advances_along_the_queue_by_index() -> void:
	var floors := _floors()

	var p0 := BuildingLayout.resolve_lobby_guest_point(floors, 0)
	var p1 := BuildingLayout.resolve_lobby_guest_point(floors, 1)

	assert_eq(p1.x - p0.x, BuildingLayout.QUEUE_SPACING)
	assert_eq(p1.y, p0.y)
