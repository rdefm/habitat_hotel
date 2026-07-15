class_name HudBar
extends PanelContainer

const SpriteFactory = preload("res://game/stubs/sprite_factory.gd")

signal pause_pressed
signal speed_1x_pressed
signal speed_2x_pressed

var _cash_label: Label
var _day_label: Label
var _phase_label: Label
var _progress_bar: ProgressBar

func _init() -> void:
	custom_minimum_size = Vector2(0, 56)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.13, 1.0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	_cash_label = SpriteFactory.make_label("$0", 14)
	row.add_child(_cash_label)
	_day_label = SpriteFactory.make_label("Day 1", 14)
	row.add_child(_day_label)
	_phase_label = SpriteFactory.make_label("Morning", 14)
	row.add_child(_phase_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var pause_btn := Button.new()
	pause_btn.text = "Pause"
	pause_btn.pressed.connect(func(): pause_pressed.emit())
	row.add_child(pause_btn)

	var speed1_btn := Button.new()
	speed1_btn.text = "1x"
	speed1_btn.pressed.connect(func(): speed_1x_pressed.emit())
	row.add_child(speed1_btn)

	var speed2_btn := Button.new()
	speed2_btn.text = "2x"
	speed2_btn.pressed.connect(func(): speed_2x_pressed.emit())
	row.add_child(speed2_btn)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(0, 6)
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)

func refresh(cash: int, day: int, phase: String, phase_elapsed: float, phase_length: float) -> void:
	_cash_label.text = "$%d" % cash
	_day_label.text = "Day %d" % day
	_phase_label.text = phase.capitalize()
	_progress_bar.max_value = max(phase_length, 0.001)
	_progress_bar.value = clampf(phase_elapsed, 0.0, phase_length)
