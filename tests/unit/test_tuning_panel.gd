extends GutTest
## Tuning menu: edits BalanceData live, pauses the game, runs actions and saves results.

const SAVE_PATH: String = "user://test_tuning_balance.tres"

var data: BalanceData
var original: BalanceData


func before_each() -> void:
	original = TuningPanel.balance
	data = BalanceData.new()
	data.resource_path = SAVE_PATH
	TuningPanel.bind(data)
	TuningPanel.select(0)
	TuningPanel.status_text = ""


func after_each() -> void:
	TuningPanel.close()
	TuningPanel.bind(original)
	get_tree().paused = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _row_index(property: StringName) -> int:
	for i: int in TuningPanel.ROWS.size():
		if TuningPanel.ROWS[i][0] == property:
			return i
	return -1


func _press_action(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = true
	TuningPanel._input(event)


func test_panel_starts_closed_and_bound_to_content_balance() -> void:
	assert_false(TuningPanel.is_open())
	assert_eq(original, ContentDB.get_item(&"balance", &"default"))


func test_every_row_is_a_float_on_balance_data() -> void:
	for row: Array in TuningPanel.ROWS:
		assert_eq(typeof(data.get(row[0])), TYPE_FLOAT, "%s should be a float" % row[0])


func test_adjust_changes_value_and_lists_it() -> void:
	TuningPanel.select(_row_index(&"dodge_distance"))
	TuningPanel.adjust(1.0)
	assert_almost_eq(data.dodge_distance, 76.0, 0.001)
	assert_string_contains(TuningPanel.changes(), "dodge_distance: 72")
	assert_string_contains(TuningPanel.changes(), "-> 76")
	TuningPanel.reset_selected()
	assert_almost_eq(data.dodge_distance, 72.0, 0.001)
	assert_eq(TuningPanel.changes(), "")


func test_values_never_go_below_zero() -> void:
	TuningPanel.select(_row_index(&"rumble_strength"))
	TuningPanel.adjust(-50.0)
	assert_eq(data.rumble_strength, 0.0)


func test_selection_wraps_over_numbers_and_actions() -> void:
	TuningPanel.select(-1)
	assert_eq(TuningPanel.selected, TuningPanel.row_count() - 1)
	assert_gt(TuningPanel.row_count(), TuningPanel.ROWS.size(), "action rows follow the numbers")
	TuningPanel.select(TuningPanel.row_count())
	assert_eq(TuningPanel.selected, 0)


func test_open_pauses_and_close_resumes() -> void:
	TuningPanel.open()
	assert_true(TuningPanel.is_open())
	assert_true(get_tree().paused)
	_press_action(&"ui_cancel")
	assert_false(TuningPanel.is_open())
	assert_false(get_tree().paused)


func test_start_button_closes_menu() -> void:
	TuningPanel.open()
	_press_action(&"pause")
	assert_false(TuningPanel.is_open())


func test_gamepad_x_resets_number() -> void:
	TuningPanel.open()
	TuningPanel.select(_row_index(&"hero_move_speed"))
	TuningPanel.adjust(2.0)
	var x: InputEventJoypadButton = InputEventJoypadButton.new()
	x.button_index = JOY_BUTTON_X
	x.pressed = true
	TuningPanel._input(x)
	assert_almost_eq(data.hero_move_speed, 110.0, 0.001)


func test_accept_runs_room_action() -> void:
	var calls: Array[int] = []
	var actions: Array[Array] = [["Test action", func() -> void: calls.append(1)]]
	TuningPanel.open(actions)
	# Rows: numbers, Save results, Reset all, room actions, Close.
	TuningPanel.select(TuningPanel.ROWS.size() + 2)
	_press_action(&"ui_accept")
	assert_eq(calls.size(), 1)


func test_close_row_closes() -> void:
	TuningPanel.open()
	TuningPanel.select(TuningPanel.row_count() - 1)
	TuningPanel.activate()
	assert_false(TuningPanel.is_open())


func test_reset_all_restores_start_values() -> void:
	for i: int in TuningPanel.ROWS.size():
		TuningPanel.select(i)
		TuningPanel.adjust(1.0)
	assert_ne(TuningPanel.changes(), "")
	TuningPanel.reset_all()
	assert_eq(TuningPanel.changes(), "")


func test_save_writes_tres_and_results_summary() -> void:
	TuningPanel.select(_row_index(&"stamina_regen"))
	TuningPanel.adjust(2.0)
	assert_eq(TuningPanel.save(), OK)
	var loaded: BalanceData = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_almost_eq(loaded.stamina_regen, 50.0, 0.001)
	var summary: String = FileAccess.get_file_as_string(TuningPanel.RESULTS_PATH)
	assert_string_contains(summary, "stamina_regen: 40.0 -> 50.0")
	assert_string_contains(summary, "dodge_distance = 72.0")
	assert_string_contains(TuningPanel.status_text, "GitHub Desktop")


func test_save_keeps_other_lines_of_existing_tres() -> void:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("[gd_resource type=\"Resource\" script_class=\"BalanceData\" format=3]\n\n[ext_resource type=\"Script\" path=\"res://scripts/resources/balance_data.gd\" id=\"1\"]\n\n[resource]\nscript = ExtResource(\"1\")\nid = &\"default\"\nhero_max_hp = 100\ndodge_distance = 72.0\n")
	file.close()
	TuningPanel.select(_row_index(&"dodge_distance"))
	TuningPanel.adjust(2.0)
	assert_eq(TuningPanel.write_tres(SAVE_PATH), OK)
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	assert_string_contains(text, "hero_max_hp = 100\n")
	assert_string_contains(text, "dodge_distance = 80.0\n")
	assert_string_contains(text, "rumble_strength = 1.0", "missing rows are added")
	assert_eq(text.count("dodge_distance"), 1)
	var loaded: BalanceData = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_almost_eq(loaded.dodge_distance, 80.0, 0.001)


func test_numbers_are_written_without_float_noise() -> void:
	assert_eq(TuningPanel.format_number(0.7000000000000001), "0.7")
	assert_eq(TuningPanel.format_number(72.0), "72.0")
	assert_eq(TuningPanel.format_number(0.15), "0.15")


func test_f4_toggles_panel() -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_F4
	press.pressed = true
	TuningPanel._input(press)
	assert_true(TuningPanel.is_open())
	TuningPanel._input(press)
	assert_false(TuningPanel.is_open())
