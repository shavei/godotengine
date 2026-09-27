extends GutTest
## The title screen reacts to a real mouse click, and the SceneRouter never locks up.

const TITLE_SCENE: PackedScene = preload("res://scenes/main/title.tscn")

var viewport: SubViewport
var title: Control


func before_each() -> void:
	# A SubViewport keeps the click away from GUT's own window.
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	add_child_autofree(viewport)
	title = TITLE_SCENE.instantiate()
	viewport.add_child(title)


func _click(pos: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = pos
	viewport.push_input(motion)
	for pressed: bool in [true, false]:
		var click: InputEventMouseButton = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = pos
		viewport.push_input(click)


func test_left_click_presses_play_button() -> void:
	await wait_process_frames(2)
	var button: Button = title.get_node("%PlayButton")
	# Keep the real transition from swapping out the test scene.
	title.get_node("%PlayButton").pressed.disconnect(title._on_play_pressed)
	watch_signals(button)
	_click(button.get_global_rect().get_center())
	assert_signal_emitted(button, "pressed", "a left click on the button presses it")


func test_nothing_covers_the_play_button() -> void:
	await wait_process_frames(2)
	var button: Button = title.get_node("%PlayButton")
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = button.get_global_rect().get_center()
	viewport.push_input(motion)
	assert_eq(viewport.gui_get_hovered_control(), button, "the button is the control under the mouse")


func test_router_fade_layer_never_blocks_the_mouse() -> void:
	for node: Node in SceneRouter.find_children("*", "Control", true, false):
		assert_eq((node as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, str(node.get_path()))


func test_router_ignores_missing_scene_without_locking() -> void:
	SceneRouter.go("res://no/such/scene.tscn")
	assert_push_error("no scene at")
	assert_false(SceneRouter.is_busy(), "a bad path must not lock the router")


func test_gamepad_a_presses_focused_button() -> void:
	await wait_process_frames(2)
	var button: Button = title.get_node("%PlayButton")
	button.pressed.disconnect(title._on_play_pressed)
	button.grab_focus()
	watch_signals(button)
	for pressed: bool in [true, false]:
		var a: InputEventJoypadButton = InputEventJoypadButton.new()
		a.button_index = JOY_BUTTON_A
		a.pressed = pressed
		viewport.push_input(a)
	assert_signal_emitted(button, "pressed", "A on a focused button presses it")


func test_title_has_tuning_room_button() -> void:
	var button: Button = title.get_node("%TuningButton")
	assert_eq(button.text, "Tuning room")
	assert_true(button.pressed.is_connected(title._on_tuning_pressed))
