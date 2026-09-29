class_name LocalInputSource
extends InputSource
## Reads the local keyboard, mouse and gamepad through the InputMap.
## Aim follows the mouse after it moves and the right stick after a gamepad is used.
## Stick aim gets melee aim assist; rumble goes to the last gamepad used.
## A released right stick keeps its aim briefly (flick, then attack), and a cursor right
## on top of the hero keeps the last aim instead of spinning it.

const MOUSE_WAKE_DISTANCE: float = 2.0
## A cursor closer than this (world px) to the hero gives no new direction.
const MOUSE_MIN_DISTANCE: float = 6.0
## A released right stick keeps its last aim this long (ms).
const STICK_AIM_HOLD_MSEC: int = 250
## The weakest rumble a pad plays, and its shortest time: lighter or shorter buzzes are
## too faint to feel on most controllers.
const MIN_RUMBLE: float = 0.25
const MIN_RUMBLE_TIME: float = 0.1

var using_mouse: bool = true
## Device id of the last gamepad that sent input, or -1.
var joy_device: int = -1

var _last_mouse_aim: Vector2 = Vector2.ZERO
var _last_stick_aim: Vector2 = Vector2.ZERO
var _last_stick_msec: int = -STICK_AIM_HOLD_MSEC


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and absf(event.axis_value) < 0.3:
			return
		using_mouse = false
		joy_device = event.device
		_use_kind(InputBindings.Kind.GAMEPAD)
	elif event is InputEventMouseButton or event is InputEventKey:
		if event is InputEventMouseButton:
			using_mouse = true
		_use_kind(InputBindings.Kind.KEYBOARD)
	elif event is InputEventMouseMotion and event.relative.length() > MOUSE_WAKE_DISTANCE:
		using_mouse = true
		_use_kind(InputBindings.Kind.KEYBOARD)


## Tells the HUD which device to name in its hints (once per switch).
func _use_kind(kind: int) -> void:
	if InputBindings.active_kind != kind:
		InputBindings.active_kind = kind
		EventBus.input_device_changed.emit(kind)


func get_move() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func get_aim(origin: Vector2) -> Vector2:
	if using_mouse:
		var viewport: Viewport = get_viewport()
		var mouse_world: Vector2 = viewport.get_canvas_transform().affine_inverse() * viewport.get_mouse_position()
		var offset: Vector2 = mouse_world - origin
		if offset.length() >= MOUSE_MIN_DISTANCE:
			_last_mouse_aim = offset.normalized()
		return _last_mouse_aim
	return stick_aim(Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down"), Time.get_ticks_msec())


## Right stick aim at time `now_msec`: the stick's direction, or the last one for a
## moment after it is let go, so a flick followed by an attack goes where it was flicked.
func stick_aim(stick: Vector2, now_msec: int) -> Vector2:
	if stick != Vector2.ZERO:
		_last_stick_aim = stick.normalized()
		_last_stick_msec = now_msec
		return _last_stick_aim
	if now_msec - _last_stick_msec < STICK_AIM_HOLD_MSEC:
		return _last_stick_aim
	return Vector2.ZERO


func wants_aim_assist() -> bool:
	return not using_mouse


func rumble(strength: float, duration: float) -> void:
	super.rumble(strength, duration)
	if using_mouse or joy_device < 0 or strength <= 0.0:
		return
	var levels: Vector3 = motor_levels(strength, duration)
	Input.start_joy_vibration(joy_device, levels.x, levels.y, levels.z)


## What a rumble asks of the pad: Vector3(weak motor, strong motor, seconds). The strong
## (low, heavy) motor carries the hit; the weak one adds a little buzz on top.
static func motor_levels(strength: float, duration: float) -> Vector3:
	if strength <= 0.0:
		return Vector3.ZERO
	var s: float = clampf(strength, MIN_RUMBLE, 1.0)
	return Vector3(s * 0.6, s, maxf(duration, MIN_RUMBLE_TIME))


func just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action) or super.just_pressed(action)
