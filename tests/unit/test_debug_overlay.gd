extends GutTest
## The F3 input inspector: toggles, reports the control under the mouse, never blocks clicks.


func after_each() -> void:
	DebugOverlay.visible = false


func _press_f3() -> void:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = KEY_F3
	key.physical_keycode = KEY_F3
	key.pressed = true
	DebugOverlay._input(key)


func test_f3_toggles_the_overlay() -> void:
	assert_false(DebugOverlay.visible, "hidden by default")
	_press_f3()
	assert_true(DebugOverlay.visible)
	_press_f3()
	assert_false(DebugOverlay.visible)


func test_overlay_never_blocks_the_mouse() -> void:
	var controls: Array[Node] = DebugOverlay.find_children("*", "Control", true, false)
	assert_gt(controls.size(), 0)
	for node: Node in controls:
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(node.get_path()))


func test_describe_reports_what_a_bug_report_needs() -> void:
	var text: String = DebugOverlay.describe()
	for part: String in ["focused:", "embedded in editor:", "Under mouse:", "Keyboard focus:", "Last click:", "router busy:"]:
		assert_string_contains(text, part)


func test_clicks_are_recorded() -> void:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(10, 20)
	DebugOverlay._input(click)
	assert_string_contains(DebugOverlay.describe(), "button 1 down at (10.0, 20.0)")
