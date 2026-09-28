extends GutTest
## The Controls menu remaps an input from a real key press and saves it.

const PATH: String = "user://test_settings/menu_settings.cfg"

var viewport: SubViewport
var menu: ControlsMenu


func before_each() -> void:
	InputBindings.reset_to_defaults()
	DirAccess.make_dir_recursive_absolute("user://test_settings")
	DirAccess.remove_absolute(PATH)
	viewport = SubViewport.new()
	viewport.size = Vector2i(640, 360)
	add_child_autofree(viewport)
	menu = load("res://scenes/ui/controls_menu.tscn").instantiate()
	menu.settings_path = PATH
	menu.back_scene = ""
	viewport.add_child(menu)
	await wait_process_frames(2)


func after_each() -> void:
	InputBindings.reset_to_defaults()


func after_all() -> void:
	DirAccess.remove_absolute(PATH)


func _press_key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	viewport.push_input(event)


func test_test_rumble_says_when_no_gamepad_is_found() -> void:
	assert_not_null(menu.find_child("RumbleButton", true, false))
	if Input.get_connected_joypads().is_empty():
		assert_eq(menu.test_rumble(), "No gamepad found. Plug one in and try again.")


func test_buttons_show_current_bindings() -> void:
	var button: Button = menu._buttons[[&"map", InputBindings.Kind.KEYBOARD]]
	assert_eq(button.text, "Tab")
	assert_eq((menu._buttons[[&"map", InputBindings.Kind.GAMEPAD]] as Button).text, "Back")


func test_picking_a_slot_then_pressing_a_key_rebinds_and_saves() -> void:
	var button: Button = menu._buttons[[&"dodge", InputBindings.Kind.KEYBOARD]]
	button.pressed.emit()
	assert_true(menu.is_listening())
	assert_eq(button.text, "Press...")
	await wait_seconds(ControlsMenu.LISTEN_GRACE + 0.05)
	_press_key(KEY_K)
	assert_false(menu.is_listening())
	assert_eq(button.text, "K")
	assert_eq(InputBindings.hint(&"dodge"), "K / A")
	InputBindings.reset_to_defaults()
	assert_true(InputBindings.load_saved(PATH), "the change was saved")
	assert_eq(InputBindings.hint(&"dodge"), "K / A")


func test_press_right_after_picking_is_ignored() -> void:
	(menu._buttons[[&"dodge", InputBindings.Kind.KEYBOARD]] as Button).pressed.emit()
	_press_key(KEY_ENTER)
	assert_true(menu.is_listening(), "the press that picked the slot is not the new input")
	assert_eq(InputBindings.hint(&"dodge"), "Space / A")


func test_wrong_kind_is_ignored_and_time_runs_out() -> void:
	(menu._buttons[[&"dodge", InputBindings.Kind.GAMEPAD]] as Button).pressed.emit()
	await wait_seconds(ControlsMenu.LISTEN_GRACE + 0.05)
	_press_key(KEY_K)
	assert_true(menu.is_listening(), "a key cannot go in the gamepad slot")
	menu._process(ControlsMenu.LISTEN_TIME)
	assert_false(menu.is_listening())
	assert_eq(InputBindings.hint(&"dodge"), "Space / A")


func test_reset_button_restores_defaults() -> void:
	InputBindings.rebind(&"dodge", InputBindings.from_description({"type": "key", "code": KEY_K}))
	(menu.find_child("ResetButton", true, false) as Button).pressed.emit()
	assert_eq(InputBindings.hint(&"dodge"), "Space / A")
	assert_eq((menu._buttons[[&"dodge", InputBindings.Kind.KEYBOARD]] as Button).text, "Space")
