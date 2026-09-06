extends GutTest

## Characterizes ticket 09's Terrace diner placement extension of
## sim/building_layout.gd: which Sim.walkin_queue entries (Walk-in Diner or
## Dining Party alike, CONTEXT.md) stand at the pass (being served) vs. the
## entrance queue (still waiting) -- terrace_diner_placements() -- how that
## bucket resolves to a world position -- resolve_terrace_diner_point() --
## and the Terrace's signage tap target -- resolve_terrace_signage_rect().
## Same shape as tests/test_station_placement.gd -- literal hand-built
## walkin_queue/dinner_jobs dicts, no autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


func _rooms() -> Dictionary:
	var out := {}
	out["cozy_nook"] = {"name": "Cozy Nook", "unlock": {"star": 1}}
	return out


func _floors() -> Array:
	return BuildingLayout.floors(_rooms(), 1)


func _entry(id: int) -> Dictionary:
	return {"id": id, "name": "Diner %d" % id, "species_id": "test_species", "party_size": 1, "patience": 100.0}


## --- terrace_diner_placements() ---

func test_an_entry_with_no_dinner_job_queues_at_the_entrance() -> void:
	var placements := BuildingLayout.terrace_diner_placements([_entry(1)], {})

	assert_eq(placements[1]["bucket"], "queue")
	assert_eq(placements[1]["index"], 0)


func test_an_entry_with_an_in_flight_dinner_job_stands_at_the_pass() -> void:
	var dinner_jobs := {"manny": {"entry_id": 1, "ticks_remaining": 5}}

	var placements := BuildingLayout.terrace_diner_placements([_entry(1)], dinner_jobs)

	assert_eq(placements[1]["bucket"], "pass")
	assert_eq(placements[1]["index"], 0)


func test_pass_and_queue_indices_are_tracked_independently_within_queue_order() -> void:
	var dinner_jobs := {"manny": {"entry_id": 2, "ticks_remaining": 5}}
	var walkin_queue := [_entry(1), _entry(2), _entry(3)]

	var placements := BuildingLayout.terrace_diner_placements(walkin_queue, dinner_jobs)

	assert_eq(placements[1]["bucket"], "queue")
	assert_eq(placements[1]["index"], 0)
	assert_eq(placements[2]["bucket"], "pass")
	assert_eq(placements[2]["index"], 0)
	assert_eq(placements[3]["bucket"], "queue")
	assert_eq(placements[3]["index"], 1, "entry 3 is the second still-waiting entry, after entry 1")


func test_every_walkin_queue_entry_gets_a_placement() -> void:
	var walkin_queue := [_entry(1), _entry(2)]

	var placements := BuildingLayout.terrace_diner_placements(walkin_queue, {})

	assert_eq(placements.keys().size(), 2, "no entry should be dropped -- the visible diner count must track walkin_queue's own size")


func test_multiple_served_entries_stack_at_distinct_pass_indices() -> void:
	var dinner_jobs := {
		"manny": {"entry_id": 1, "ticks_remaining": 5},
		"shelly": {"entry_id": 2, "ticks_remaining": 5},
	}
	var walkin_queue := [_entry(1), _entry(2)]

	var placements := BuildingLayout.terrace_diner_placements(walkin_queue, dinner_jobs)

	assert_eq(placements[1]["bucket"], "pass")
	assert_eq(placements[1]["index"], 0)
	assert_eq(placements[2]["bucket"], "pass")
	assert_eq(placements[2]["index"], 1)


## --- resolve_terrace_diner_point() ---

func test_resolve_terrace_diner_point_for_a_pass_bucket_uses_the_diner_grid() -> void:
	var floors := _floors()
	var spot := BuildingLayout.resolve_terrace_diner_spot(floors, 1, 0)

	var point := BuildingLayout.resolve_terrace_diner_point(floors, {"bucket": "pass", "index": 0})

	assert_eq(point, spot)


func test_resolve_terrace_diner_point_for_a_queue_bucket_uses_the_entrance_queue() -> void:
	var floors := _floors()
	var queue_point := BuildingLayout.resolve_terrace_entrance_queue_point(floors, 1, 0)

	var point := BuildingLayout.resolve_terrace_diner_point(floors, {"bucket": "queue", "index": 0})

	assert_eq(point, queue_point)


func test_resolve_terrace_diner_point_at_a_later_index_advances_along_its_own_bucket() -> void:
	var floors := _floors()
	var queue_point_1 := BuildingLayout.resolve_terrace_entrance_queue_point(floors, 1, 1)

	var point := BuildingLayout.resolve_terrace_diner_point(floors, {"bucket": "queue", "index": 1})

	assert_eq(point, queue_point_1)


## --- resolve_terrace_signage_rect() ---

func test_terrace_signage_rect_is_distinct_from_the_terraces_other_anchors() -> void:
	var floors := _floors()
	var signage := BuildingLayout.resolve_terrace_signage_rect(floors)
	var kitchen_pass: Vector2 = BuildingLayout.resolve_anchor(floors, 1, "kitchen_pass")
	var diner_spot := BuildingLayout.resolve_terrace_diner_spot(floors, 1, 0)
	var queue_point := BuildingLayout.resolve_terrace_entrance_queue_point(floors, 1, 0)

	assert_false(signage.has_point(kitchen_pass), "signage shouldn't overlap the kitchen_pass Station post")
	assert_false(signage.has_point(diner_spot), "signage shouldn't overlap the diner grid")
	assert_false(signage.has_point(queue_point), "signage shouldn't overlap the entrance queue")


func test_terrace_signage_rect_translates_by_the_terrace_floors_own_top_y() -> void:
	var floors := _floors()
	var terrace_top_y: float = BuildingLayout.floor_bottom_y(floors, 1) - float(floors[1]["height"])

	var signage := BuildingLayout.resolve_terrace_signage_rect(floors)

	assert_eq(signage.position.y - terrace_top_y, BuildingLayout.TERRACE_SIGNAGE_RECT_LOCAL.position.y)
