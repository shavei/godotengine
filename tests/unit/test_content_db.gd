extends GutTest
## ContentDB loads data folders without errors. Content arrives in M3+,
## at which point the content integrity checks (docs/ARCHITECTURE.md Section 11) go here.


func test_loads_data_root_without_crashing() -> void:
	var loaded: int = ContentDB.load_all(ContentDB.DATA_ROOT)
	assert_true(loaded >= 0)


func test_unknown_items_return_null_and_empty() -> void:
	assert_null(ContentDB.get_item(&"powers", &"does_not_exist"))
	assert_eq(ContentDB.get_all(&"no_such_category").size(), 0)
	assert_eq(ContentDB.count(&"no_such_category"), 0)


func test_missing_root_loads_nothing() -> void:
	assert_eq(ContentDB.load_all("res://no_such_folder"), 0)
	ContentDB.load_all(ContentDB.DATA_ROOT)
