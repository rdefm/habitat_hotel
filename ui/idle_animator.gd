class_name IdleAnimator
extends Node

## Drives the "still by default, occasional random idle-animation clip"
## ambient behaviour for a character slot that stands at rest for a while --
## a Staffer at their post/nook and a settled Room occupant by day. Wraps a
## CharacterSprite (which stays a dumb renderer, per that class's own header
## comment) and owns only the timing/selection state around it:
## sim/building_layout.gd's resolve_character_idle_clips() names which clips
## (if any) exist for a character; this class picks one at random every few
## seconds, plays it once, and falls back to the plain "idle" still
## (resolve_character_sprite(..., "idle")) the rest of the time.
##
## Not wired into lobby guests or Terrace diners: ui/hotel_world.gd fully
## destroys and recreates those actors on essentially every frame (their own
## Patience decay changes the rebuild signature every tick, per tickets
## 09/10's own comments), which would reset this class's timer before it
## ever fired. They render their still frame only, same as before this class
## existed, until a future pass gives their rebuild loop a stable per-guest
## identity to hang this state off instead.
##
## configure() is cheap to call every frame: naming the same kind/
## character_id as last time is a no-op, so a rebuild that recreates the
## OWNING actor but not this timer (a Staffer reassignment, a Room bay
## refresh) never restarts a clip already in flight or re-rolls the wait
## before the next one.

const BuildingLayout = preload("res://sim/building_layout.gd")
const CharacterSprite = preload("res://ui/character_sprite.gd")

const MIN_INTERVAL := 3.0
const MAX_INTERVAL := 7.0
const CLIP_FPS := 8.0

var _sprite: CharacterSprite
var _kind: String = ""
var _character_id: String = ""
var _clips: Array = []
var _timer: float = 0.0
var _playing: bool = false


func _init(sprite: CharacterSprite) -> void:
	_sprite = sprite


## Same (kind, character_id) as the last call is a no-op -- see class doc.
## A genuine change (first configure, or a different character taking this
## slot) shows the still immediately and rolls a fresh wait.
func configure(kind: String, character_id: String) -> void:
	if kind == _kind and character_id == _character_id:
		return
	_kind = kind
	_character_id = character_id
	_clips = BuildingLayout.resolve_character_idle_clips(kind, character_id)
	_playing = false
	_roll_timer()
	_show_still()


## Stops driving the wrapped sprite -- for when the slot switches to a
## non-idle state some OTHER code path now renders directly (a Room occupant
## falling asleep, a Kitchen Staffer picking up a dinner Job), so this timer
## can't fire mid-way and stomp that state with an idle clip.
func deactivate() -> void:
	_kind = ""
	_character_id = ""
	_clips = []
	_playing = false


func _process(delta: float) -> void:
	if _kind == "" or _playing or _clips.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_play_random_clip()


func _show_still() -> void:
	_sprite.configure(BuildingLayout.resolve_character_sprite(_kind, _character_id, "idle"))


func _play_random_clip() -> void:
	_playing = true
	var clip: Dictionary = _clips[Rng.randi_range(0, _clips.size() - 1)]
	_sprite.configure(clip, CLIP_FPS, false, _on_clip_finished)


func _on_clip_finished() -> void:
	_playing = false
	_roll_timer()
	_show_still()


func _roll_timer() -> void:
	_timer = MIN_INTERVAL + Rng.randf() * (MAX_INTERVAL - MIN_INTERVAL)
