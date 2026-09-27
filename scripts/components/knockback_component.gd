class_name KnockbackComponent
extends Node
## Holds a push velocity that fades out. The owner adds `velocity` to its movement.

## px/s lost per second.
@export var friction: float = 1200.0
## Multiplier on incoming pushes. Heavy enemies use less than 1.
@export var weight_scale: float = 1.0

var velocity: Vector2 = Vector2.ZERO


func apply(impulse: Vector2) -> void:
	velocity += impulse * weight_scale


func tick(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func is_active() -> bool:
	return velocity != Vector2.ZERO


func clear() -> void:
	velocity = Vector2.ZERO
