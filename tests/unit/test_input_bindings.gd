extends GutTest
## Controls remapping rules (InputBindings).

const PATH: String = "user://test_settings/settings.cfg"
const K: int = InputBindings.Kind.KEYBOARD
const G: int = InputBindings.Kind.GAMEPAD


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_settings")
	DirAccess.remove_absolute(PATH)
	InputBindings.reset_to_defaults()
	InputBindings.active_kind = K


func after_all() -> void:
	DirAccess.remove_absolute(PATH)
	InputBindings.reset_to_defaults()
	InputBindings.active_kind = K


func _key(code: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	return event


func _button(index: JoyButton) -> InputEventJoypadButton:
	var event: InputEventJoypadButton = InputEventJoypadButton.new()
	event.button_index = index
	event.pressed = true
	event.device = 0
	return event


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	return event


func test_every_listed_action_has_both_kinds() -> void:
	for action: StringName in InputBindings.action_ids():
		assert_not_null(InputBindings.primary(action, K), "%s keyboard" % action)
		assert_not_null(InputBindings.primary(action, G), "%s gamepad" % action)


func test_rebinding_a_free_key() -> void:
	assert_eq(InputBindings.rebind(&"dodge", _key(KEY_K)), &"")
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", K)), "K")
	var press: InputEventKey = _key(KEY_K)
	assert_true(press.is_action(&"dodge"))
	assert_false(_key(KEY_SPACE).is_action(&"dodge"), "the old key is gone")


func test_keyboard_rebind_leaves_gamepad_alone() -> void:
	InputBindings.rebind(&"dodge", _key(KEY_K))
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", G)), "A")


func test_taking_another_actions_input_swaps_them() -> void:
	# Dodge takes Flask's key (1); Flask gets Dodge's old key (Space).
	assert_eq(InputBindings.rebind(&"dodge", _key(KEY_1)), &"flask")
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", K)), "1")
	assert_eq(InputBindings.event_name(InputBindings.primary(&"flask", K)), "Space")
	assert_true(_key(KEY_SPACE).is_action(&"flask"))
	assert_false(_key(KEY_1).is_action(&"flask"))


func test_gamepad_swap() -> void:
	assert_eq(InputBindings.rebind(&"attack", _button(JOY_BUTTON_A)), &"dodge")
	assert_eq(InputBindings.event_name(InputBindings.primary(&"attack", G)), "A")
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", G)), "X")


func test_taking_an_extra_key_removes_it_without_a_swap() -> void:
	# The arrow keys are extra move inputs; WASD stay the main ones.
	assert_eq(InputBindings.rebind(&"map", _key(KEY_UP)), &"")
	assert_false(_key(KEY_UP).is_action(&"move_up"))
	assert_eq(InputBindings.event_name(InputBindings.primary(&"move_up", K)), "W")
	assert_true(_key(KEY_UP).is_action(&"map"))


func test_rebinding_to_own_extra_key_keeps_one_copy() -> void:
	InputBindings.rebind(&"move_up", _key(KEY_UP))
	assert_eq(InputBindings.event_name(InputBindings.primary(&"move_up", K)), "Up")
	var ups: int = 0
	for event: InputEvent in InputMap.action_get_events(&"move_up"):
		if InputBindings.same_input(event, _key(KEY_UP)):
			ups += 1
	assert_eq(ups, 1)


func test_triggers_and_sticks_bind_but_the_aim_stick_does_not() -> void:
	assert_true(InputBindings.accepts(_axis(JOY_AXIS_TRIGGER_LEFT, 1.0), G))
	assert_true(InputBindings.accepts(_axis(JOY_AXIS_LEFT_Y, -0.9), G))
	assert_false(InputBindings.accepts(_axis(JOY_AXIS_LEFT_Y, -0.3), G), "small nudges do not count")
	assert_false(InputBindings.accepts(_axis(JOY_AXIS_RIGHT_X, 1.0), G), "the right stick aims")
	assert_false(InputBindings.accepts(_key(KEY_K), G))
	assert_false(InputBindings.accepts(_button(JOY_BUTTON_A), K))
	InputBindings.rebind(&"map", _axis(JOY_AXIS_TRIGGER_LEFT, 0.8))
	assert_eq(InputBindings.event_name(InputBindings.primary(&"map", G)), "LT")


func test_menus_go_back_with_escape_or_b() -> void:
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	assert_true(InputMap.action_has_event(&"ui_cancel", escape))
	assert_true(InputMap.action_has_event(&"ui_cancel", _button(JOY_BUTTON_B)))


func test_hints_name_one_device_at_a_time() -> void:
	assert_eq(InputBindings.hint_for(&"power_1", K), "Q")
	assert_eq(InputBindings.hint_for(&"power_1", G), "LB")
	assert_eq(InputBindings.move_hint_for(K), "WASD")
	assert_eq(InputBindings.move_hint_for(G), "stick")
	var pad: String = InputBindings.combat_help([["Map", &"map"]], G)
	assert_string_contains(pad, "Attack X")
	assert_string_contains(pad, "Aim right stick")
	assert_string_contains(pad, "Map Back")
	assert_false(pad.contains("Left click"), "no keyboard inputs in the gamepad line")
	var keys: String = InputBindings.combat_help([["Map", &"map"]], K)
	assert_string_contains(keys, "Attack Left click")
	assert_false(keys.contains(" X"), "no gamepad inputs in the keyboard line")
	assert_lt(pad.length(), InputBindings.combat_help([["Map", &"map"]]).length(), "one device is shorter")


func test_the_help_line_follows_the_device_in_use() -> void:
	var label: Label = Label.new()
	add_child_autofree(label)
	CombatHelp.attach(label, [["Map", &"map"]])
	await wait_process_frames(1)
	assert_string_contains(label.text, "Attack Left click")
	InputBindings.active_kind = G
	EventBus.input_device_changed.emit(G)
	assert_string_contains(label.text, "Attack X")


func test_back_paddles_have_names() -> void:
	InputBindings.rebind(&"map", _button(JOY_BUTTON_PADDLE2))
	assert_eq(InputBindings.event_name(InputBindings.primary(&"map", G)), "Paddle 2")
	assert_eq(InputBindings.hint(&"map"), "Tab / Paddle 2")


func test_save_and_load_round_trip() -> void:
	InputBindings.rebind(&"dodge", _key(KEY_K))
	InputBindings.rebind(&"map", _button(JOY_BUTTON_Y))
	assert_eq(InputBindings.save(PATH), OK)
	InputBindings.reset_to_defaults()
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", K)), "Space")
	assert_true(InputBindings.load_saved(PATH))
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", K)), "K")
	assert_eq(InputBindings.event_name(InputBindings.primary(&"map", G)), "Y")


func test_loading_without_a_file_changes_nothing() -> void:
	assert_false(InputBindings.load_saved("user://test_settings/missing.cfg"))
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", K)), "Space")


func test_broken_entries_are_skipped() -> void:
	InputBindings.apply_dict({"dodge": {"keyboard": {"type": "joy_button", "button": 2}, "gamepad": "junk"}, "nope": {}})
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", K)), "Space")
	assert_eq(InputBindings.event_name(InputBindings.primary(&"dodge", G)), "A")


func test_reset_restores_defaults() -> void:
	InputBindings.rebind(&"dodge", _key(KEY_1))
	InputBindings.reset_to_defaults()
	assert_eq(InputBindings.hint(&"dodge"), "Space / A")
	assert_eq(InputBindings.hint(&"flask"), "1 / D-pad up")


func test_hints_follow_bindings() -> void:
	assert_eq(InputBindings.hint(&"map"), "Tab / Back")
	assert_eq(InputBindings.hint(&"attack"), "Left click / X")
	assert_eq(InputBindings.hint(&"fusion"), "F / RT")
	assert_eq(InputBindings.move_hint(), "WASD / stick")
	InputBindings.rebind(&"move_up", _key(KEY_I))
	InputBindings.rebind(&"move_up", _button(JOY_BUTTON_DPAD_UP))
	assert_eq(InputBindings.move_hint(), "IASD / D-pad up/Left stick left/Left stick down/Left stick right")
	assert_string_contains(InputBindings.combat_help([["Map", &"map"]]), "Map Tab / Back")
