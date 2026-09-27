extends GutTest
## Save round trip, backup and fallback behavior (docs/ARCHITECTURE.md Section 10).

const TEST_DIR: String = "user://test_saves"
const SLOT: int = 7

var _original_dir: String


func before_each() -> void:
	_original_dir = SaveManager.save_dir
	SaveManager.save_dir = TEST_DIR
	SaveManager.delete_slot(SLOT)


func after_each() -> void:
	SaveManager.delete_slot(SLOT)
	SaveManager.save_dir = _original_dir


func test_round_trip_keeps_data_and_adds_version() -> void:
	var data: Dictionary = {"run_count": 3, "heroes": {"0": {"level": 2}}}
	assert_eq(SaveManager.save_data(SLOT, data), OK)
	var loaded: Dictionary = SaveManager.load_data(SLOT)
	assert_eq(int(loaded["run_count"]), 3)
	assert_eq(int(loaded["heroes"]["0"]["level"]), 2)
	assert_eq(int(loaded["version"]), SaveManager.SAVE_VERSION)


func test_second_save_writes_backup_of_first() -> void:
	SaveManager.save_data(SLOT, {"run_count": 1})
	SaveManager.save_data(SLOT, {"run_count": 2})
	assert_true(FileAccess.file_exists(SaveManager.backup_path(SLOT)))
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.backup_path(SLOT)))
	assert_eq(int(backup["run_count"]), 1)


func test_corrupt_save_falls_back_to_backup() -> void:
	SaveManager.save_data(SLOT, {"run_count": 1})
	SaveManager.save_data(SLOT, {"run_count": 2})
	var file: FileAccess = FileAccess.open(SaveManager.slot_path(SLOT), FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_eq(int(SaveManager.load_data(SLOT)["run_count"]), 1)


func test_missing_slot_loads_empty() -> void:
	assert_false(SaveManager.has_save(SLOT))
	assert_eq(SaveManager.load_data(SLOT), {})


func test_save_emits_signal() -> void:
	watch_signals(EventBus)
	SaveManager.save_data(SLOT, {})
	assert_signal_emitted_with_parameters(EventBus, "game_saved", [SLOT])
