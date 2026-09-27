class_name StatusComponent
extends Node
## Timed status effects keyed by id (&"burn", &"chill", ...). Effects themselves arrive
## with powers in M3; this only tracks what is active, how long, and how many stacks.

signal status_added(id: StringName)
signal status_removed(id: StringName)

## id -> { "time": float, "stacks": int }
var _active: Dictionary = {}


func apply(id: StringName, duration: float, max_stacks: int = 1) -> void:
	if _active.has(id):
		var entry: Dictionary = _active[id]
		entry["time"] = maxf(entry["time"], duration)
		entry["stacks"] = mini(entry["stacks"] + 1, max_stacks)
		return
	_active[id] = {"time": duration, "stacks": 1}
	status_added.emit(id)


func has(id: StringName) -> bool:
	return _active.has(id)


func stacks(id: StringName) -> int:
	return _active[id]["stacks"] if _active.has(id) else 0


func remove(id: StringName) -> void:
	if _active.erase(id):
		status_removed.emit(id)


func tick(delta: float) -> void:
	for id: StringName in _active.keys():
		var entry: Dictionary = _active[id]
		entry["time"] -= delta
		if entry["time"] <= 0.0:
			remove(id)
