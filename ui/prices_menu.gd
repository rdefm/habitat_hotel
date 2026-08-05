class_name PricesMenu
extends VBoxContainer

## Prices menu: adjust each unlocked room type's price multiplier. Pricier
## rooms earn more per stay but price out guests whose budget tier can't
## tolerate the markup (see MatchHint's "too_expensive" walk-away reason).

var _rows: Dictionary = {} # room_type_id -> {mult_label, rate_label}


func _ready() -> void:
	custom_minimum_size = Vector2(520, 320)

	var header := Label.new()
	header.text = "Higher prices earn more per stay, but budget-limited guests may walk away instead of booking."
	header.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(header)

	var room_ids := GameState.rooms.keys()
	room_ids.sort()
	for room_type_id in room_ids:
		if not GameState.can_build_room_type(room_type_id):
			continue
		add_child(_build_row(room_type_id))


func _build_row(room_type_id: String) -> Control:
	var rt: Dictionary = GameState.rooms[room_type_id]
	var pricing: Dictionary = GameState.balance.get("pricing", {})
	var step: float = float(pricing.get("step", 0.1))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var name_label := Label.new()
	name_label.text = rt["name"]
	name_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(name_label)

	var minus_btn := Button.new()
	minus_btn.text = "-"
	minus_btn.pressed.connect(_on_adjust.bind(room_type_id, -step))
	row.add_child(minus_btn)

	var mult_label := Label.new()
	mult_label.custom_minimum_size = Vector2(60, 0)
	row.add_child(mult_label)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.pressed.connect(_on_adjust.bind(room_type_id, step))
	row.add_child(plus_btn)

	var rate_label := Label.new()
	row.add_child(rate_label)

	_rows[room_type_id] = {"mult_label": mult_label, "rate_label": rate_label}
	_refresh_row(room_type_id)
	return row


func _on_adjust(room_type_id: String, delta: float) -> void:
	var current := GameState.price_multiplier_for(room_type_id)
	GameState.set_price_multiplier(room_type_id, current + delta)
	_refresh_row(room_type_id)


func _refresh_row(room_type_id: String) -> void:
	var rt: Dictionary = GameState.rooms[room_type_id]
	var mult := GameState.price_multiplier_for(room_type_id)
	var row_labels: Dictionary = _rows[room_type_id]
	row_labels["mult_label"].text = "%.1fx" % mult
	row_labels["rate_label"].text = "= %d/night" % int(round(float(rt["base_rate"]) * mult))
