class_name SimEvents
extends RefCounted

## Typed event outbox. sim/ appends events here each tick; game/ drains them
## once per frame and animates accordingly. Never mutated from game/.

var _outbox: Array[Dictionary] = []

func emit(type: String, data: Dictionary = {}) -> void:
	_outbox.append({"type": type, "data": data})

func drain() -> Array[Dictionary]:
	var out := _outbox
	_outbox = []
	return out

func peek() -> Array[Dictionary]:
	return _outbox.duplicate(true)
