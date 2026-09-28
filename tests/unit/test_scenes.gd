extends GutTest
## Every scene in the project must load and instantiate cleanly.

const SCENES: Array[String] = [
	"res://scenes/main/main.tscn",
	"res://scenes/main/title.tscn",
	"res://scenes/actors/hero/hero.tscn",
	"res://scenes/actors/training_dummy/training_dummy.tscn",
	"res://scenes/run/test_room.tscn",
	"res://scenes/run/wave_room.tscn",
	"res://scenes/run/tuning_room.tscn",
	"res://scenes/actors/enemy/enemy.tscn",
	"res://scenes/actors/enemy/thorn_arrow.tscn",
	"res://scenes/actors/enemy/thorn_patch.tscn",
	"res://scenes/actors/enemy/root_wall.tscn",
	"res://scenes/ui/hud.tscn",
	"res://scenes/run/room.tscn",
	"res://scenes/ui/run_map.tscn",
	"res://scenes/ui/controls_menu.tscn",
	"res://scenes/ui/results.tscn",
	"res://scenes/ui/choice_screen.tscn",
	"res://scenes/ui/gift_ceremony.tscn",
	"res://scenes/village/village.tscn",
	"res://scenes/village/villager.tscn",
	"res://scenes/abilities/power_projectile.tscn",
	"res://scenes/abilities/power_burst.tscn",
	"res://scenes/abilities/power_patch.tscn",
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
	assert_true(GameState.profile.heroes.has(GameState.LOCAL_PLAYER_ID))
	assert_eq(GameState.hero_state(GameState.LOCAL_PLAYER_ID).level, 1)


func test_test_room_runs_without_errors() -> void:
	var room: Node = load("res://scenes/run/test_room.tscn").instantiate()
	add_child_autofree(room)
	await wait_physics_frames(10)
	var hero: Hero = room.get_node("Actors/Hero")
	assert_true(hero.state_machine.is_in(&"Move"))
	assert_eq(room.get_node("Hud").hp_label.text, "100 / 100")


func test_wave_room_starts_the_first_wave() -> void:
	var room: Node = load("res://scenes/run/wave_room.tscn").instantiate()
	add_child_autofree(room)
	await wait_physics_frames(10)
	var director: WaveDirector = room.get_node("WaveDirector")
	assert_eq(director.tracker.current_wave, 0)
	assert_eq(room.get_node("%WaveLabel").text, "Wave 1 / 3")
	await wait_seconds(1.0)
	assert_eq(get_tree().get_nodes_in_group(Enemy.GROUP).size(), 3, "three Sproutlings")


func test_tuning_room_menu_spawns_enemies_on_demand() -> void:
	var room: Node = load("res://scenes/run/tuning_room.tscn").instantiate()
	add_child_autofree(room)
	await wait_physics_frames(10)
	var director: WaveDirector = room.get_node("WaveDirector")
	assert_null(director.tracker, "no enemies until asked")
	room.open_menu()
	assert_true(TuningPanel.is_open())
	assert_true(get_tree().paused)
	room.spawn_enemies()
	assert_false(TuningPanel.is_open(), "spawning closes the menu")
	assert_false(get_tree().paused)
	assert_eq(director.tracker.current_wave, 0)
	room.spawn_enemies()
	assert_eq(director.tracker.current_wave, 0, "no second spawn while enemies are out")
	TuningPanel.close()


func test_tuning_room_menu_starts_a_boss_fight() -> void:
	var room: Node = load("res://scenes/run/tuning_room.tscn").instantiate()
	add_child_autofree(room)
	await wait_physics_frames(10)
	var director: WaveDirector = room.get_node("WaveDirector")
	room.fight_boss(false)
	assert_eq(director.encounter.id, &"mother_toad")
	await wait_seconds(1.0)
	var hud: Hud = room.get_node("Hud")
	assert_true(hud.boss_panel.visible, "the boss bar shows")
	assert_eq(hud.boss_name.text, "Mother Toad")
