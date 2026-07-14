class_name PolicyMenu
extends VBoxContainer

## Global setting: how the Matcher seats arriving guests when their needs
## can't be perfectly met by a vacant room. See sim/matcher.gd for the
## actual decision logic this switches between.

const OPTIONS := [
	{
		"id": "strict_match",
		"name": "Perfect Fit Only",
		"description": "Guests are only seated in a room that meets every one of their needs. If no such room is vacant, they walk away -- even if other rooms are empty. Fewer guests, but nobody suffers a mismatched stay.",
	},
	{
		"id": "fill_vacancies",
		"name": "Fill Vacancies",
		"description": "If no perfect-fit room is vacant, guests are seated in any vacant room big enough to hold them, at a satisfaction penalty. Only walk away if every room is full or unaffordable. More occupancy, but risks weaker reviews.",
	},
]

var _rows: Dictionary = {} # policy_id -> {button, info}


func _ready() -> void:
	custom_minimum_size = Vector2(520, 320)

	var header := Label.new()
	header.text = "How should arriving guests be seated when their needs can't be perfectly met?"
	header.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(header)

	for option in OPTIONS:
		add_child(_build_row(option))

	_refresh()


func _build_row(option: Dictionary) -> Control:
	var row := VBoxContainer.new()

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	row.add_child(top)

	var btn := Button.new()
	btn.toggle_mode = true
	btn.text = option["name"]
	btn.pressed.connect(_on_select.bind(option["id"]))
	top.add_child(btn)

	var info := Label.new()
	info.text = option["description"]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	_rows[option["id"]] = {"button": btn, "info": info}
	return row


func _on_select(policy_id: String) -> void:
	GameState.matcher_policy = policy_id
	_refresh()


func _refresh() -> void:
	for policy_id in _rows.keys():
		var row_widgets: Dictionary = _rows[policy_id]
		var btn: Button = row_widgets["button"]
		btn.button_pressed = (policy_id == GameState.matcher_policy)
