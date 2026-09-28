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


func test_run_save_round_trip_and_delete() -> void:
	assert_false(SaveManager.has_run(SLOT))
	assert_eq(SaveManager.save_run(SLOT, {"region": "mossy_hollow", "room": 3}), OK)
	assert_true(SaveManager.has_run(SLOT))
	assert_eq(int(SaveManager.load_run(SLOT)["room"]), 3)
	SaveManager.delete_run(SLOT)
	assert_false(SaveManager.has_run(SLOT))
	assert_eq(SaveManager.load_run(SLOT), {})


func test_delete_slot_also_deletes_its_run() -> void:
	SaveManager.save_run(SLOT, {"room": 1})
	SaveManager.delete_slot(SLOT)
	assert_false(SaveManager.has_run(SLOT))


func test_profile_saves_and_loads_through_game_state() -> void:
	var original_slot: int = GameState.slot
	var original_profile: ProfileState = GameState.profile
	GameState.slot = SLOT
	GameState.new_profile()
	GameState.hero_state(0).level = 6
	GameState.hero_state(0).bank.add(Wallet.COINS, 55)
	assert_eq(GameState.save_profile(), OK)
	GameState.new_profile()
	assert_eq(GameState.hero_state(0).level, 1)
	GameState.load_profile()
	assert_eq(GameState.hero_state(0).level, 6)
	assert_eq(GameState.hero_state(0).bank.amount(Wallet.COINS), 55)
	GameState.slot = original_slot
	GameState.profile = original_profile


func test_a_broken_run_save_is_dropped() -> void:
	var original_slot: int = GameState.slot
	GameState.slot = SLOT
	SaveManager.save_run(SLOT, {"region": "no_such_region"})
	assert_false(GameState.load_saved_run())
	assert_false(SaveManager.has_run(SLOT), "a save that cannot load never blocks the title")
	assert_null(GameState.run)
	GameState.slot = original_slot
