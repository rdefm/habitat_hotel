extends GutTest

## Characterizes ticket 07's extension of sim/building_layout.gd: the
## Station post anchor (resolve_station_post_anchor(), including the new
## Terrace kitchen_pass anchor) and Staffer placement bucketing
## (staffer_bucket()/staffer_placements()/resolve_staffer_point()). Same
## shape as tests/test_anchor_registry.gd -- literal hand-built `rooms`
## dicts and plain `stars` ints, no autoloads, no nodes.

const BuildingLayout = preload("res://sim/building_layout.gd")


func _rooms() -> Dictionary:
	var out := {}
	out["cozy_nook"] = {"name": "Cozy Nook", "unlock": {"star": 1}}
	return out


func _floors() -> Array:
	return BuildingLayout.floors(_rooms(), 1)


## --- resolve_station_post_anchor() ---

func test_reception_post_is_the_front_desk() -> void:
	var floors := _floors()

	var post := BuildingLayout.resolve_station_post_anchor(floors, "reception")

	assert_eq(post, BuildingLayout.resolve_anchor(floors, 0, "front_desk"))


func test_housekeeping_post_is_the_supply_closet() -> void:
	var floors := _floors()

	var post := BuildingLayout.resolve_station_post_anchor(floors, "housekeeping")

	assert_eq(post, BuildingLayout.resolve_anchor(floors, 0, "supply_closet"))


func test_kitchen_post_is_the_terrace_pass_upstairs() -> void:
	var floors := _floors()

	var post := BuildingLayout.resolve_station_post_anchor(floors, "kitchen")

	assert_eq(post, BuildingLayout.resolve_anchor(floors, 1, "kitchen_pass"))


func test_kitchen_pass_is_distinct_from_the_terraces_other_anchors() -> void:
	var floors := _floors()

	var pass_point: Vector2 = BuildingLayout.resolve_anchor(floors, 1, "kitchen_pass")
	var diner_spot := BuildingLayout.resolve_terrace_diner_spot(floors, 1, 0)
	var queue_point := BuildingLayout.resolve_terrace_entrance_queue_point(floors, 1, 0)

	assert_ne(pass_point, diner_spot)
	assert_ne(pass_point, queue_point)


func test_the_three_station_posts_are_mutually_distinct() -> void:
	var floors := _floors()

	var reception := BuildingLayout.resolve_station_post_anchor(floors, "reception")
	var housekeeping := BuildingLayout.resolve_station_post_anchor(floors, "housekeeping")
	var kitchen := BuildingLayout.resolve_station_post_anchor(floors, "kitchen")

	assert_ne(reception, housekeeping)
	assert_ne(reception, kitchen)
	assert_ne(housekeeping, kitchen)


## --- staffer_bucket() ---

func test_an_unassigned_station_id_buckets_to_the_nook() -> void:
	assert_eq(BuildingLayout.staffer_bucket(""), "nook")


func test_a_station_id_buckets_to_its_own_post() -> void:
	assert_eq(BuildingLayout.staffer_bucket("reception"), "post:reception")


## --- staffer_placements() ---

func test_an_assigned_staffer_lands_in_their_stations_post_bucket() -> void:
	var stations := {"reception": ["biscuit"], "housekeeping": [], "kitchen": []}

	var placements := BuildingLayout.staffer_placements(stations, ["biscuit"])

	assert_eq(placements["biscuit"]["bucket"], "post:reception")
	assert_eq(placements["biscuit"]["index"], 0)


func test_a_staffer_assigned_to_no_station_lands_in_the_nook() -> void:
	var stations := {"reception": ["biscuit"], "housekeeping": [], "kitchen": []}

	var placements := BuildingLayout.staffer_placements(stations, ["biscuit", "manny"])

	assert_eq(placements["manny"]["bucket"], "nook")
	assert_eq(placements["manny"]["index"], 0)


func test_two_staffers_at_the_same_post_get_distinct_stable_indices_sorted_alphabetically() -> void:
	var stations := {"reception": ["shelly", "biscuit"], "housekeeping": [], "kitchen": []}

	var placements := BuildingLayout.staffer_placements(stations, ["biscuit", "shelly"])

	assert_eq(placements["biscuit"]["index"], 0, "biscuit sorts before shelly")
	assert_eq(placements["shelly"]["index"], 1)


func test_two_unassigned_staffers_share_the_nook_at_distinct_indices() -> void:
	var stations := {"reception": [], "housekeeping": [], "kitchen": []}

	var placements := BuildingLayout.staffer_placements(stations, ["shelly", "manny"])

	assert_eq(placements["manny"]["bucket"], "nook")
	assert_eq(placements["shelly"]["bucket"], "nook")
	assert_eq(placements["manny"]["index"], 0, "manny sorts before shelly")
	assert_eq(placements["shelly"]["index"], 1)


func test_every_known_staffer_appears_exactly_once() -> void:
	var stations := {"reception": ["biscuit"], "housekeeping": ["shelly"], "kitchen": []}

	var placements := BuildingLayout.staffer_placements(stations, ["biscuit", "manny", "shelly"])

	assert_eq(placements.keys().size(), 3)


## --- resolve_staffer_point() ---

func test_resolve_staffer_point_at_index_zero_sits_exactly_on_the_anchor() -> void:
	var floors := _floors()
	var anchor: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "staff_nook")

	var point := BuildingLayout.resolve_staffer_point(floors, {"bucket": "nook", "index": 0})

	assert_eq(point, anchor)


func test_resolve_staffer_point_offsets_later_indices_off_the_anchor() -> void:
	var floors := _floors()
	var anchor: Vector2 = BuildingLayout.resolve_anchor(floors, 0, "front_desk")

	var point := BuildingLayout.resolve_staffer_point(floors, {"bucket": "post:reception", "index": 1})

	assert_eq(point, anchor + BuildingLayout.STAFFER_STACK_OFFSET)


func test_resolve_staffer_point_for_a_post_bucket_uses_the_stations_post_anchor() -> void:
	var floors := _floors()
	var kitchen_post := BuildingLayout.resolve_station_post_anchor(floors, "kitchen")

	var point := BuildingLayout.resolve_staffer_point(floors, {"bucket": "post:kitchen", "index": 0})

	assert_eq(point, kitchen_post)
