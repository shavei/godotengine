class_name InputSource
extends Node
## Where an actor's commands come from (docs/ARCHITECTURE.md Section 9).
## This base class is a scripted source: set `move` and `aim`, call press(). Tests and
## (later) network peers use it; LocalInputSource reads the keyboard, mouse and gamepad.

var move: Vector2 = Vector2.ZERO
## Aim direction, or ZERO to aim where the actor is moving.
var aim: Vector2 = Vector2.ZERO

var _pressed: Dictionary = {}


func press(action: StringName) -> void:
	_pressed[action] = true


func get_move() -> Vector2:
	return move.limit_length(1.0)


func get_aim(_origin: Vector2) -> Vector2:
	return aim.normalized()


## True once per press. Call once per physics frame per action.
func just_pressed(action: StringName) -> bool:
	return _pressed.erase(action)
