extends GutTest
## Every scene in the project must load and instantiate cleanly.

const SCENES: Array[String] = [
	"res://scenes/main/main.tscn",
	"res://scenes/main/title.tscn",
	"res://scenes/actors/hero/hero.tscn",
	"res://scenes/actors/training_dummy/training_dummy.tscn",
	"res://scenes/run/test_room.tscn",
	"res://scenes/ui/hud.tscn",
]


func test_scenes_instantiate() -> void:
	for path: String in SCENES:
		var packed: PackedScene = load(path)
		assert_not_null(packed, "could not load %s" % path)
		if packed == null:
			continue
		var node: Node = packed.instantiate()
		assert_not_null(node, "could not instantiate %s" % path)
		node.free()


func test_main_scene_setting_points_to_boot_scene() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), SCENES[0])


func test_game_state_new_profile_is_keyed_by_player_id() -> void:
	GameState.new_profile()
	assert_true(GameState.has_profile())
	assert_true(GameState.profile["heroes"].has(str(GameState.LOCAL_PLAYER_ID)))


func test_test_room_runs_without_errors() -> void:
	var room: Node = load("res://scenes/run/test_room.tscn").instantiate()
	add_child_autofree(room)
	await wait_physics_frames(10)
	var hero: Hero = room.get_node("Actors/Hero")
	assert_true(hero.state_machine.is_in(&"Move"))
	assert_eq(room.get_node("Hud").hp_label.text, "100 / 100")
