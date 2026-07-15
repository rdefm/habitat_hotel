class_name ReportsMenu
extends VBoxContainer

## Reports menu: daily log (every day_summary so far) plus a weekly rollup
## (7-day aggregates). Pure read-over of GameState.day_history.

func _ready() -> void:
	custom_minimum_size = Vector2(560, 420)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	tabs.add_child(_build_daily_tab())
	tabs.add_child(_build_weekly_tab())
	tabs.set_tab_title(0, "Daily Log")
	tabs.set_tab_title(1, "Weekly Report")


func _build_daily_tab() -> Control:
	var scroll := ScrollContainer.new()
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var history: Array = GameState.day_history
	if history.is_empty():
		list.add_child(_line("No days completed yet -- come back after Day 1's Night phase."))
	for summary in history:
		list.add_child(_line("Day %d: cash %+d (now %d), occupancy %.0f%%, %d checkout(s) [+%d/~%d/-%d], %d arrival(s), %d turned away" % [
			summary["day"], summary["cash_delta"], summary["cash_end"], summary["occupancy_rate"] * 100.0,
			summary["checkouts"], summary["positive_reviews"], summary["neutral_reviews"], summary["negative_reviews"],
			summary["arrivals"],
			summary["walked_away_mismatch"] + summary["walked_away_full"] + summary["walked_away_too_expensive"],
		]))
	return scroll


func _build_weekly_tab() -> Control:
	var scroll := ScrollContainer.new()
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var history: Array = GameState.day_history
	if history.is_empty():
		list.add_child(_line("No completed weeks yet."))
	var week_index := 1
	var i := 0
	while i < history.size():
		var week_slice: Array = history.slice(i, mini(i + 7, history.size()))
		list.add_child(_line(_summarize_week(week_index, week_slice)))
		week_index += 1
		i += 7
	return scroll


func _summarize_week(week_index: int, days: Array) -> String:
	var cash_delta := 0
	var checkouts := 0
	var positive := 0
	var neutral := 0
	var negative := 0
	var sat_total := 0.0
	for d in days:
		cash_delta += int(d["cash_delta"])
		checkouts += int(d["checkouts"])
		positive += int(d["positive_reviews"])
		neutral += int(d["neutral_reviews"])
		negative += int(d["negative_reviews"])
		sat_total += float(d["avg_satisfaction"])
	var avg_sat := sat_total / days.size()
	return "Week %d (days %d-%d): cash %+d, %d checkouts [+%d/~%d/-%d], avg satisfaction %.0f" % [
		week_index, int(days[0]["day"]), int(days[days.size() - 1]["day"]), cash_delta, checkouts, positive, neutral, negative, avg_sat,
	]


func _line(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	return l
