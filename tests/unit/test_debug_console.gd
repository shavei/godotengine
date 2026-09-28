extends GutTest
## The debug console (docs/ARCHITECTURE.md Section 11): ConsoleCommands on the profile,
## and the DebugConsole autoload's scene commands (god_mode, skip_room).

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero/hero.tscn")

var _original_profile: ProfileState
var balance: BalanceData
var profile: ProfileState


func before_each() -> void:
	_original_profile = GameState.profile
	GameState.new_profile()
	profile = GameState.profile
	balance = GameState.balance()
	DebugConsole.save_on_change = false


func after_each() -> void:
	DebugConsole.close()
	DebugConsole.save_on_change = true
	Hero.god_mode = false
	GameState.profile = _original_profile


func _run(line: String) -> Dictionary:
	return ConsoleCommands.run(ConsoleCommands.words(line), profile, GameState.LOCAL_PLAYER_ID, balance, _powers())


func _powers() -> Array[PowerData]:
	var result: Array[PowerData] = []
	for item: Resource in ContentDB.get_all(&"powers"):
		result.append(item as PowerData)
	return result


func test_words_ignore_case_and_extra_spaces() -> void:
	assert_eq(ConsoleCommands.words("  Set_TP   Smith 7 "), PackedStringArray(["set_tp", "smith", "7"]))


func test_give_power_waits_at_the_shrine() -> void:
	var result: Dictionary = _run("give_power fire")
	assert_true(result["ok"])
	assert_true(result["changed"])
	assert_eq(result["text"], "Fire waits at the Shrine.")
	assert_eq(PowerOffer.waiting_power(profile.hero(0)), &"fire")


func test_give_power_names_the_powers_when_wrong() -> void:
	var result: Dictionary = _run("give_power lava")
	assert_false(result["ok"])
	assert_false(result["changed"])
	assert_eq(result["text"], "No power called lava. Try: fire, frost, growth, stone")
	assert_true(profile.hero(0).power_offer.is_empty())


func test_set_tp_ranks_a_villager_up() -> void:
	profile.village.find(&"smith").power_id = &"fire"
	var result: Dictionary = _run("set_tp smith 7")
	assert_true(result["ok"])
	assert_eq(result["text"], "The smith has 7 TP (Master).")
	assert_eq(TrainingSystem.rank(profile.village.find(&"smith"), balance), TrainingSystem.MASTER)


func test_set_tp_needs_a_villager_holding_a_power() -> void:
	assert_eq(_run("set_tp smith 7")["text"], "The smith holds no power yet. Give one first.")
	assert_string_contains(_run("set_tp baker 3")["text"], "No baker lives here.")
	assert_eq(_run("set_tp smith lots")["text"], "Usage: set_tp <villager> <points>")


func test_add_renown_raises_the_level_and_is_saved() -> void:
	var result: Dictionary = _run("add_renown 10")
	assert_true(result["ok"])
	assert_eq(RenownSystem.points(profile.village, balance), 10)
	assert_gt(RenownSystem.level(profile.village, balance), 1)
	assert_eq(VillageState.from_dict(profile.village.to_dict()).bonus_renown, 10)
	_run("add_renown -50")
	assert_eq(profile.village.bonus_renown, 0, "never below what the village earned")


func test_unknown_commands_point_to_help() -> void:
	assert_eq(_run("fly")["text"], "Unknown command: fly. Type help.")
	var help: String = _run("help")["text"]
	for command: String in ["give_power", "set_tp", "add_renown", "skip_room", "god_mode"]:
		assert_string_contains(help, command)


func test_console_runs_profile_commands_on_the_game_state() -> void:
	DebugConsole.run("give_power stone")
	assert_eq(PowerOffer.waiting_power(GameState.hero_state(0)), &"stone")
	assert_string_contains("\n".join(DebugConsole.lines), "Stone waits at the Shrine.")


func test_god_mode_stops_all_damage() -> void:
	var hero: Hero = HERO_SCENE.instantiate()
	add_child_autofree(hero)
	await wait_process_frames(1)
	DebugConsole.run("god_mode")
	assert_true(Hero.god_mode)
	assert_eq(hero.health.take_damage(50), 0)
	assert_eq(hero.health.hp, hero.health.max_hp)
	DebugConsole.run("god_mode")
	assert_false(Hero.god_mode)
	assert_gt(hero.health.take_damage(5), 0)


func test_skip_room_needs_a_run_room() -> void:
	assert_eq(DebugConsole.run("skip_room"), "Only in a run room that is not clear yet.")


func test_opening_pauses_the_game_and_closing_restores_it() -> void:
	DebugConsole.open()
	assert_true(DebugConsole.visible)
	assert_true(get_tree().paused)
	DebugConsole.close()
	assert_false(DebugConsole.visible)
	assert_false(get_tree().paused)
