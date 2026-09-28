class_name GameCamera
extends Camera2D
## Follows a target and shakes on EventBus.camera_shake_requested.
## Shake uses trauma (0 to 1), offset grows with trauma squared so small hits stay subtle.
## Follows on physics ticks, like the actors: with physics interpolation on (project
## setting) Godot then draws camera and actors between ticks together, so nothing jitters.

@export var target: Node2D
@export var max_offset: float = 7.5
@export var trauma_decay: float = 1.8
## Accessibility slider (docs/GDD.md Section 18). 0 turns shake off.
@export_range(0.0, 1.0) var shake_scale: float = 1.0

var trauma: float = 0.0


func _ready() -> void:
	EventBus.camera_shake_requested.connect(add_trauma)
	if target != null:
		global_position = target.global_position
		reset_smoothing()
		reset_physics_interpolation()


func add_trauma(amount: float) -> void:
	trauma = minf(1.0, trauma + amount)


func _physics_process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		global_position = target.global_position
	if trauma > 0.0:
		trauma = maxf(0.0, trauma - trauma_decay * delta)
		var strength: float = max_offset * trauma * trauma * shake_scale
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength
	else:
		offset = Vector2.ZERO
