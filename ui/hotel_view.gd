class_name HotelView
extends ScrollContainer

## The building cross-section's outer scaffold (ticket 02, ADR-0016): one
## vertically-scrolling container stacking Reception (fixed, ground floor),
## Terrace (fixed, directly above Reception), and one Floor per unlocked
## Room type above that, ordered by ascending unlock star -- replacing the
## old flat stack of separate panels main_screen.gd used to mount directly.
## This ticket is structure only: every floor's actual content
## (ReceptionPanel/StationPanel/TerracePanel/HotelPanel) is untouched,
## still today's cards/buttons -- the actor reskin is later tickets' job.
##
## _stack lists its children top-to-bottom in screen order, which is the
## building's bottom-to-top order in reverse: HotelPanel's Room floors
## (itself already highest-star-first internally, see
## hotel_panel.gd's _floor_sort_descending) first, then Terrace, then the
## Station row, with Reception's arrival queue last -- so Reception's queue
## ends up lowest on screen (the ticket's "fixed Reception floor at the
## bottom") and a newly-unlocked, higher-star Room floor stacks in above
## the existing ones. _stack's ALIGNMENT_END keeps that group glued to the
## bottom of the visible area while it's shorter than the screen (blank sky
## above); once it overflows, alignment has no effect on already-full space
## and the ScrollContainer simply scrolls -- no floor ever shrinks to fit,
## per the ticket's "floor height stays fixed" requirement.
##
## Room floor Build Slot / built-instance-cell drop-target/tap semantics
## (Party-seat, Staffer-stack) live entirely on hotel_panel.gd's
## RoomCellButton and are untouched by this rework -- main_screen.gd still
## connects to hotel_panel's own slot_selected/seat_attempted signals
## exactly as before, just reached via this container's hotel_panel field.

const HotelPanel = preload("res://ui/hotel_panel.gd")
const ReceptionPanel = preload("res://ui/reception_panel.gd")
const StationPanel = preload("res://ui/station_panel.gd")
const TerracePanel = preload("res://ui/terrace_panel.gd")

## Forwarded onto hotel_panel before it's added to the tree -- must be set
## (if desired) before this node enters the tree itself, since HotelPanel
## reads it during the refresh() its own _ready() triggers.
@export var interactive: bool = false

var hotel_panel: HotelPanel
var terrace_panel: TerracePanel
var reception_panel: ReceptionPanel
var station_panel: StationPanel

var _stack: VBoxContainer


func _ready() -> void:
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	_stack = VBoxContainer.new()
	_stack.alignment = BoxContainer.ALIGNMENT_END
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.add_theme_constant_override("separation", 14)
	add_child(_stack)

	hotel_panel = HotelPanel.new()
	hotel_panel.interactive = interactive
	hotel_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stack.add_child(hotel_panel)

	terrace_panel = TerracePanel.new()
	_stack.add_child(terrace_panel)

	station_panel = StationPanel.new()
	_stack.add_child(station_panel)

	reception_panel = ReceptionPanel.new()
	_stack.add_child(reception_panel)
