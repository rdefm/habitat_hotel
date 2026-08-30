class_name ReceptionMenu
extends VBoxContainer

## The Reception structure's modal (ticket 07, ADR-0016): bundles the four
## retired bottom-menu-bar buttons -- Prices, Hire, Reports, Reviews -- as
## tabs of one TabContainer, mirroring ui/reports_menu.gd's own Daily
## Log/Weekly Report tabs. Each tab is the existing menu widget mounted
## unchanged; only their entry point moves from a standalone bottom-bar
## button to a tab here.
##
## Opened by tapping the Reception structure (main_screen._on_reception_tapped
## -> open_menu()), which pauses the Clock like every other generic-overlay
## menu, same as ui/terrace_menu.gd.

const PricesMenu = preload("res://ui/prices_menu.gd")
const HireMenu = preload("res://ui/hire_menu.gd")
const ReportsMenu = preload("res://ui/reports_menu.gd")
const ReviewsMenu = preload("res://ui/reviews_menu.gd")


func _ready() -> void:
	custom_minimum_size = Vector2(600, 460)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(tabs)

	tabs.add_child(PricesMenu.new())
	tabs.add_child(HireMenu.new())
	tabs.add_child(ReportsMenu.new())
	tabs.add_child(ReviewsMenu.new())
	tabs.set_tab_title(0, "Prices")
	tabs.set_tab_title(1, "Hire")
	tabs.set_tab_title(2, "Reports")
	tabs.set_tab_title(3, "Reviews")
