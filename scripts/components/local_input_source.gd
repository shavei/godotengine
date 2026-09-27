class_name LocalInputSource
extends InputSource
## Reads the local keyboard, mouse and gamepad through the InputMap.
## Aim follows the mouse after it moves and the right stick after a gamepad is used.

const MOUSE_WAKE_DISTANCE: float = 2.0

var using_mouse: bool = true


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.3:
			return
		using_mouse = false
	elif event is InputEventMouseButton:
		using_mouse = true
	elif event is InputEventMouseMotion and event.relative.length() > MOUSE_WAKE_DISTANCE:
		using_mouse = true


func get_move() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func get_aim(origin: Vector2) -> Vector2:
	if using_mouse:
		var viewport: Viewport = get_viewport()
		var mouse_world: Vector2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
		return (mouse_world - origin).normalized()
	return Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down").normalized()


func just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action) or super.just_pressed(action)
