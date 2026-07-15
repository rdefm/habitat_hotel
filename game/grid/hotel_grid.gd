class_name HotelGrid
extends VBoxContainer

const RoomTile = preload("res://game/grid/room_tile.gd")

signal tile_tapped(plot_id: int)
signal tile_drop_requested(plot_id: int, party_id: int)

var _tiles: Dictionary = {}

func build(rooms: Array, room_types: Dictionary, floors: int, plots_per_floor: int) -> void:
	for child in get_children():
		child.queue_free()
	_tiles.clear()

	var by_plot: Dictionary = {}
	for room in rooms:
		by_plot[int(room["plot_id"])] = room

	add_theme_constant_override("separation", 4)
	for floor_i in range(floors):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		add_child(row)
		for col in range(plots_per_floor):
			var plot_id := floor_i * plots_per_floor + col
			var room: Dictionary = by_plot.get(plot_id, {"plot_id": plot_id, "room_type": "", "state": "empty", "stay_id": -1})
			var room_type: Dictionary = room_types.get(room["room_type"], {})
			var tile := RoomTile.new()
			tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			tile.setup(room, room_type)
			tile.tapped_room.connect(func(pid: int): tile_tapped.emit(pid))
			tile.drop_requested.connect(func(pid: int, party_id: int): tile_drop_requested.emit(pid, party_id))
			row.add_child(tile)
			_tiles[plot_id] = tile

func refresh(rooms: Array, room_types: Dictionary) -> void:
	for room in rooms:
		var tile: RoomTile = _tiles.get(int(room["plot_id"]))
		if tile != null:
			tile.setup(room, room_types.get(room["room_type"], {}))

func apply_glow(fit_by_plot: Dictionary) -> void:
	for plot_id in _tiles.keys():
		var tile: RoomTile = _tiles[plot_id]
		tile.set_glow(fit_by_plot.get(plot_id, "NONE"))

func clear_glow() -> void:
	for tile in _tiles.values():
		tile.set_glow("NONE")

func flash_fresh(plot_id: int) -> void:
	var tile: RoomTile = _tiles.get(plot_id)
	if tile != null:
		tile.flash_fresh()

func set_cleaning_progress(plot_id: int, fraction: float) -> void:
	var tile: RoomTile = _tiles.get(plot_id)
	if tile != null:
		tile.set_cleaning_progress(fraction)
