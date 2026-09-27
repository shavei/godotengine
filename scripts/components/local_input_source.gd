class_name LocalInputSource
extends InputSource
## Reads the local keyboard, mouse and gamepad through the InputMap.
## Aim follows the mouse after it moves and the right stick after a gamepad is used.
## Stick aim gets melee aim assist; rumble goes to the last gamepad used.

const MOUSE_WAKE_DISTANCE: float = 2.0

var using_mouse: bool = true
## Device id of the last gamepad that sent input, or -1.
var joy_device: int = -1


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.3:
			return
		using_mouse = false
		joy_device = event.device
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


func wants_aim_assist() -> bool:
	return not using_mouse


func rumble(strength: float, duration: float) -> void:
	super.rumble(strength, duration)
	if using_mouse or joy_device < 0 or strength <= 0.0:
		return
	var s: float = clampf(strength, 0.0, 1.0)
	Input.start_joy_vibration(joy_device, s, s * 0.6, duration)


func just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action) or super.just_pressed(action)
