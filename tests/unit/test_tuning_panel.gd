extends GutTest
## F4 tuning panel: edits BalanceData live, resets, lists changes and saves.

const SAVE_PATH: String = "user://test_tuning_balance.tres"

var data: BalanceData
var original: BalanceData


func before_each() -> void:
	original = TuningPanel.balance
	data = BalanceData.new()
	data.resource_path = SAVE_PATH
	TuningPanel.bind(data)
	TuningPanel.select(0)


func after_each() -> void:
	TuningPanel.bind(original)
	TuningPanel.visible = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _row_index(property: StringName) -> int:
	for i: int in TuningPanel.ROWS.size():
		if TuningPanel.ROWS[i][0] == property:
			return i
	return -1


func test_panel_starts_hidden_and_bound_to_content_balance() -> void:
	assert_false(TuningPanel.visible)
	assert_eq(original, ContentDB.get_item(&"balance", &"default"))


func test_every_row_is_a_float_on_balance_data() -> void:
	for row: Array in TuningPanel.ROWS:
		assert_eq(typeof(data.get(row[0])), TYPE_FLOAT, "%s should be a float" % row[0])


func test_adjust_changes_value_and_lists_it() -> void:
	TuningPanel.select(_row_index(&"dodge_distance"))
	TuningPanel.adjust(1.0)
	assert_almost_eq(data.dodge_distance, 76.0, 0.001)
	assert_string_contains(TuningPanel.changes(), "dodge_distance = 76")
	TuningPanel.reset_selected()
	assert_almost_eq(data.dodge_distance, 72.0, 0.001)
	assert_eq(TuningPanel.changes(), "")


func test_values_never_go_below_zero() -> void:
	TuningPanel.select(_row_index(&"rumble_strength"))
	TuningPanel.adjust(-50.0)
	assert_eq(data.rumble_strength, 0.0)


func test_selection_wraps() -> void:
	TuningPanel.select(-1)
	assert_eq(TuningPanel.selected, TuningPanel.ROWS.size() - 1)
	TuningPanel.select(TuningPanel.ROWS.size())
	assert_eq(TuningPanel.selected, 0)


func test_save_writes_file_and_new_values_become_defaults() -> void:
	TuningPanel.select(_row_index(&"stamina_regen"))
	TuningPanel.adjust(2.0)
	assert_eq(TuningPanel.save(), OK)
	assert_eq(TuningPanel.changes(), "", "saved values are the new defaults")
	var loaded: BalanceData = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	assert_almost_eq(loaded.stamina_regen, 50.0, 0.001)


func test_f4_toggles_panel() -> void:
	var press: InputEventKey = InputEventKey.new()
	press.physical_keycode = KEY_F4
	press.pressed = true
	TuningPanel._input(press)
	assert_true(TuningPanel.visible)
	TuningPanel._input(press)
	assert_false(TuningPanel.visible)
