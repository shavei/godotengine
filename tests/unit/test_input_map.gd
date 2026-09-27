extends GutTest
## Every gameplay action from docs/GDD.md Section 7.1 must exist with both
## a keyboard/mouse binding and a gamepad binding (aim is gamepad only; mouse aims).

const ACTIONS_WITH_BOTH: Array[StringName] = [
	&"move_left", &"move_right", &"move_up", &"move_down",
	&"attack", &"dodge", &"power_1", &"power_2", &"power_3",
	&"fusion", &"flask", &"interact", &"pause",
]
const GAMEPAD_ONLY: Array[StringName] = [&"aim_left", &"aim_right", &"aim_up", &"aim_down"]


func test_actions_have_keyboard_and_gamepad_bindings() -> void:
	for action: StringName in ACTIONS_WITH_BOTH:
		assert_true(InputMap.has_action(action), "missing action %s" % action)
		if not InputMap.has_action(action):
			continue
		var events: Array[InputEvent] = InputMap.action_get_events(action)
		assert_true(events.any(_is_keyboard_or_mouse), "%s has no keyboard/mouse binding" % action)
		assert_true(events.any(_is_gamepad), "%s has no gamepad binding" % action)


func test_aim_actions_have_gamepad_bindings() -> void:
	for action: StringName in GAMEPAD_ONLY:
		assert_true(InputMap.has_action(action), "missing action %s" % action)
		if InputMap.has_action(action):
			assert_true(InputMap.action_get_events(action).any(_is_gamepad), "%s has no gamepad binding" % action)


func test_no_key_bound_to_two_gameplay_actions() -> void:
	var seen: Dictionary = {}
	for action: StringName in ACTIONS_WITH_BOTH:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var code: int = (event as InputEventKey).physical_keycode
				assert_false(seen.has(code), "key %d bound to %s and %s" % [code, seen.get(code), action])
				seen[code] = action


func _is_keyboard_or_mouse(event: InputEvent) -> bool:
	return event is InputEventKey or event is InputEventMouseButton


func _is_gamepad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion
