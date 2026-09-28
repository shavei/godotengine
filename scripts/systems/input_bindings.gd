class_name InputBindings
extends RefCounted
## Player remapping of controls (docs/GDD.md Section 13, Settings). Each remappable action
## has one keyboard/mouse input and one gamepad input the player can change; defaults come
## from project.godot. Taking an input another action uses swaps the two, so no action is
## ever left without one. Saved to user://settings.cfg and applied at boot.

enum Kind { KEYBOARD, GAMEPAD }

const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "input"

## [action, label] in menu order.
const ACTIONS: Array[Array] = [
	[&"move_up", "Move up"],
	[&"move_down", "Move down"],
	[&"move_left", "Move left"],
	[&"move_right", "Move right"],
	[&"attack", "Attack"],
	[&"dodge", "Dodge"],
	[&"flask", "Flask"],
	[&"interact", "Interact"],
	[&"power_1", "Power 1"],
	[&"power_2", "Power 2"],
	[&"power_3", "Power 3"],
	[&"fusion", "Fusion"],
	[&"map", "Map"],
	[&"pause", "Pause"],
]
## The right stick always aims, so it cannot be given to an action.
const AIM_AXES: Array[int] = [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]
## A stick or trigger must move this far to count as a press when remapping.
const AXIS_THRESHOLD: float = 0.6

const JOY_BUTTON_NAMES: Dictionary = {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Back", JOY_BUTTON_GUIDE: "Home", JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
	JOY_BUTTON_MISC1: "Share", JOY_BUTTON_TOUCHPAD: "Touchpad",
	JOY_BUTTON_PADDLE1: "Paddle 1", JOY_BUTTON_PADDLE2: "Paddle 2",
	JOY_BUTTON_PADDLE3: "Paddle 3", JOY_BUTTON_PADDLE4: "Paddle 4",
}
const MOUSE_NAMES: Dictionary = {
	MOUSE_BUTTON_LEFT: "Left click", MOUSE_BUTTON_RIGHT: "Right click",
	MOUSE_BUTTON_MIDDLE: "Middle click", MOUSE_BUTTON_XBUTTON1: "Mouse back",
	MOUSE_BUTTON_XBUTTON2: "Mouse forward",
}


static func action_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for row: Array in ACTIONS:
		result.append(row[0])
	return result


static func kind_of(event: InputEvent) -> int:
	if event is InputEventKey or event is InputEventMouseButton:
		return Kind.KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return Kind.GAMEPAD
	return -1


## True if `event` is a press the player may bind in a `kind` slot.
static func accepts(event: InputEvent, kind: int) -> bool:
	if kind_of(event) != kind or not event.is_pressed() or event.is_echo():
		return false
	if event is InputEventMouseButton:
		return MOUSE_NAMES.has((event as InputEventMouseButton).button_index)
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return not AIM_AXES.has(motion.axis) and absf(motion.axis_value) >= AXIS_THRESHOLD
	return true


## The action's changeable input of `kind` (its first one), or null.
static func primary(action: StringName, kind: int) -> InputEvent:
	for event: InputEvent in InputMap.action_get_events(action):
		if kind_of(event) == kind:
			return event
	return null


## Binds `event` as the action's input of its kind. Returns the action it was taken
## from (which gets this action's old input), or &"" if it was free.
static func rebind(action: StringName, event: InputEvent) -> StringName:
	var kind: int = kind_of(event)
	var fresh: InputEvent = normalized(event)
	var old: InputEvent = primary(action, kind)
	if old != null and same_input(old, fresh):
		return &""
	var taken_from: StringName = &""
	for other: StringName in action_ids():
		if other == action:
			continue
		var other_primary: InputEvent = primary(other, kind)
		for existing: InputEvent in InputMap.action_get_events(other):
			if not same_input(existing, fresh):
				continue
			# Taking another action's main input swaps; an extra input is just removed.
			if same_input(existing, other_primary) and old != null:
				_replace(other, existing, normalized(old))
				taken_from = other
			else:
				InputMap.action_erase_event(other, existing)
	_set_primary(action, kind, fresh)
	return taken_from


## Every remappable action's inputs, for saving: action -> { "keyboard": {...}, "gamepad": {...} }.
static func to_dict() -> Dictionary:
	var result: Dictionary = {}
	for action: StringName in action_ids():
		var entry: Dictionary = {}
		for kind: int in [Kind.KEYBOARD, Kind.GAMEPAD]:
			var event: InputEvent = primary(action, kind)
			if event != null:
				entry[_kind_key(kind)] = describe(event)
		result[String(action)] = entry
	return result


## Applies saved inputs. Unknown actions and broken entries are skipped.
static func apply_dict(data: Dictionary) -> void:
	for action: StringName in action_ids():
		var entry: Variant = data.get(String(action))
		if not entry is Dictionary:
			continue
		for kind: int in [Kind.KEYBOARD, Kind.GAMEPAD]:
			var event: InputEvent = from_description((entry as Dictionary).get(_kind_key(kind), {}))
			if event != null and kind_of(event) == kind:
				_set_primary(action, kind, event)


static func save(path: String = SETTINGS_PATH) -> Error:
	var config: ConfigFile = ConfigFile.new()
	config.load(path)
	if config.has_section(SECTION):
		config.erase_section(SECTION)
	var data: Dictionary = to_dict()
	for action: String in data:
		config.set_value(SECTION, action, data[action])
	return config.save(path)


## Loads saved inputs if there are any. Returns true if something was applied.
static func load_saved(path: String = SETTINGS_PATH) -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(path) != OK or not config.has_section(SECTION):
		return false
	var data: Dictionary = {}
	for action: String in config.get_section_keys(SECTION):
		data[action] = config.get_value(SECTION, action)
	apply_dict(data)
	return true


## Back to the project defaults for every action.
static func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()


static func same_input(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null or a.get_class() != b.get_class():
		return false
	if a is InputEventKey:
		return _key_code(a) == _key_code(b)
	if a is InputEventMouseButton:
		return (a as InputEventMouseButton).button_index == (b as InputEventMouseButton).button_index
	if a is InputEventJoypadButton:
		return (a as InputEventJoypadButton).button_index == (b as InputEventJoypadButton).button_index
	if a is InputEventJoypadMotion:
		var ma: InputEventJoypadMotion = a
		var mb: InputEventJoypadMotion = b
		return ma.axis == mb.axis and signf(ma.axis_value) == signf(mb.axis_value)
	return false


## A clean copy for the InputMap: any device, not pressed, sticks at full tilt.
static func normalized(event: InputEvent) -> InputEvent:
	return from_description(describe(event))


static func describe(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": _key_code(event)}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": (event as InputEventMouseButton).button_index}
	if event is InputEventJoypadButton:
		return {"type": "joy_button", "button": (event as InputEventJoypadButton).button_index}
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		return {"type": "joy_axis", "axis": motion.axis, "sign": 1 if motion.axis_value >= 0.0 else -1}
	return {}


static func from_description(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	match d.get("type", ""):
		"key":
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = int(d.get("code", 0)) as Key
			return key if key.physical_keycode != KEY_NONE else null
		"mouse":
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = int(d.get("button", 0)) as MouseButton
			return mouse if MOUSE_NAMES.has(mouse.button_index) else null
		"joy_button":
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.device = -1
			button.button_index = int(d.get("button", -1)) as JoyButton
			return button if button.button_index >= 0 else null
		"joy_axis":
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.device = -1
			motion.axis = int(d.get("axis", -1)) as JoyAxis
			motion.axis_value = 1.0 if int(d.get("sign", 1)) >= 0 else -1.0
			return motion if motion.axis >= 0 else null
	return null


## Short name for screens: "Space", "Left click", "A", "RT", "Left stick up".
static func event_name(event: InputEvent) -> String:
	if event == null:
		return "none"
	if event is InputEventKey:
		return OS.get_keycode_string(_key_code(event))
	if event is InputEventMouseButton:
		return MOUSE_NAMES.get((event as InputEventMouseButton).button_index, "Mouse")
	if event is InputEventJoypadButton:
		var index: int = (event as InputEventJoypadButton).button_index
		return JOY_BUTTON_NAMES.get(index, "Button %d" % index)
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event
		var positive: bool = motion.axis_value >= 0.0
		match motion.axis:
			JOY_AXIS_TRIGGER_LEFT:
				return "LT"
			JOY_AXIS_TRIGGER_RIGHT:
				return "RT"
			JOY_AXIS_LEFT_X:
				return "Left stick right" if positive else "Left stick left"
			JOY_AXIS_LEFT_Y:
				return "Left stick down" if positive else "Left stick up"
			JOY_AXIS_RIGHT_X:
				return "Right stick right" if positive else "Right stick left"
			JOY_AXIS_RIGHT_Y:
				return "Right stick down" if positive else "Right stick up"
		return "Axis %d" % motion.axis
	return "?"


## "Tab / Back": the action's keyboard and gamepad inputs, for on-screen hints.
static func hint(action: StringName) -> String:
	var names: PackedStringArray = []
	for kind: int in [Kind.KEYBOARD, Kind.GAMEPAD]:
		var event: InputEvent = primary(action, kind)
		if event != null:
			names.append(event_name(event))
	return " / ".join(names)


## "WASD / stick", or the four inputs spelled out when they are remapped.
static func move_hint() -> String:
	var keys: PackedStringArray = []
	var pads: PackedStringArray = []
	var all_left_stick: bool = true
	for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		keys.append(event_name(primary(action, Kind.KEYBOARD)))
		var pad: InputEvent = primary(action, Kind.GAMEPAD)
		pads.append(event_name(pad))
		var motion: InputEventJoypadMotion = pad as InputEventJoypadMotion
		all_left_stick = all_left_stick and motion != null and motion.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]
	var short_keys: bool = keys.size() == 4 and Array(keys).all(func(k: String) -> bool: return k.length() == 1)
	var key_text: String = "".join(keys) if short_keys else "/".join(keys)
	return "%s / %s" % [key_text, "stick" if all_left_stick else "/".join(pads)]


## The combat help line shown at the bottom of rooms. `extra` adds ["Label", action] pairs.
static func combat_help(extra: Array[Array] = []) -> String:
	var parts: PackedStringArray = [
		"Move %s" % move_hint(),
		"Aim mouse / right stick",
		"Attack %s" % hint(&"attack"),
		"Dodge %s" % hint(&"dodge"),
		"Flask %s" % hint(&"flask"),
	]
	for pair: Array in extra:
		parts.append("%s %s" % [pair[0], hint(pair[1])])
	return "    ".join(parts)


static func _set_primary(action: StringName, kind: int, event: InputEvent) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	var placed: bool = false
	for existing: InputEvent in events:
		if kind_of(existing) == kind and not placed:
			InputMap.action_add_event(action, event)
			placed = true
		elif not same_input(existing, event):
			InputMap.action_add_event(action, existing)
	if not placed:
		InputMap.action_add_event(action, event)


## Swaps `target` for `event` in the same place, so extra inputs keep their order.
static func _replace(action: StringName, target: InputEvent, event: InputEvent) -> void:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	InputMap.action_erase_events(action)
	for existing: InputEvent in events:
		InputMap.action_add_event(action, event if existing == target else existing)


static func _key_code(event: InputEventKey) -> Key:
	return event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode


static func _kind_key(kind: int) -> String:
	return "keyboard" if kind == Kind.KEYBOARD else "gamepad"
