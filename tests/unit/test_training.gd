extends GutTest
## Training and Renown (M5 PR 1): the training tick after every run, rank-ups, Renown
## points and levels, the Healer moving in at Renown 2, and how the village and the
## results screen show them.

const VILLAGE_SCENE: PackedScene = preload("res://scenes/village/village.tscn")
const RESULTS_SCENE: PackedScene = preload("res://scenes/ui/results.tscn")

var _balance: BalanceData
var _original_profile: ProfileState
var _original_context: Dictionary


func before_each() -> void:
	_balance = ContentDB.get_item(&"balance", &"default") as BalanceData
	_original_profile = GameState.profile
	_original_context = SceneRouter.context
	SceneRouter.context = {}
	GameState.new_profile()
	GameState.profile.first_gift_done = true


func after_each() -> void:
	GameState.profile = _original_profile
	SceneRouter.context = _original_context
	GameState.run = null


func _village() -> VillageState:
	return GameState.profile.village


func _give(villager_id: StringName, power_id: StringName, level: int = 1) -> VillagerState:
	return GiftSystem.give(_village(), _village().index_of(villager_id), power_id, level)


func _open() -> Village:
	var scene: Village = VILLAGE_SCENE.instantiate()
	scene.save_on_change = false
	add_child_autofree(scene)
	await wait_physics_frames(2)
	return scene


# --- TrainingSystem --------------------------------------------------------------------

func test_the_design_thresholds_are_3_and_7() -> void:
	assert_eq(_balance.adept_tp, 3)
	assert_eq(_balance.master_tp, 7)


func test_a_tick_trains_only_villagers_holding_a_power() -> void:
	var farmer: VillagerState = _give(&"farmer", &"growth")
	TrainingSystem.tick(_village(), _balance)
	assert_eq(farmer.training_points, 1)
	assert_eq(_village().find(&"smith").training_points, 0, "no power, no training")


func test_a_tick_reports_rank_ups_at_3_and_7() -> void:
	var farmer: VillagerState = _give(&"farmer", &"growth", 3)
	var rank_ups: Array[RankUp] = TrainingSystem.tick(_village(), _balance)
	assert_eq(rank_ups.size(), 1, "2 TP to 3 TP is Adept")
	assert_eq(rank_ups[0].villager_id, &"farmer")
	assert_eq(rank_ups[0].power_id, &"growth")
	assert_eq(rank_ups[0].rank_before, TrainingSystem.NOVICE)
	assert_eq(rank_ups[0].rank_after, TrainingSystem.ADEPT)
	assert_false(rank_ups[0].is_master())
	for i: int in 3:
		assert_eq(TrainingSystem.tick(_village(), _balance).size(), 0)
	rank_ups = TrainingSystem.tick(_village(), _balance)
	assert_eq(farmer.training_points, 7)
	assert_eq(rank_ups.size(), 1)
	assert_true(rank_ups[0].is_master())
	assert_eq(TrainingSystem.tick(_village(), _balance).size(), 0, "nothing above Master")


func test_a_level_1_gift_reaches_master_after_7_runs() -> void:
	var smith: VillagerState = _give(&"smith", &"fire")
	GameState.profile.training_due = 7
	TrainingSystem.train_due(GameState.profile, _balance)
	assert_eq(TrainingSystem.rank(smith, _balance), TrainingSystem.MASTER)
	assert_eq(GameState.profile.training_due, 0)


func test_train_due_applies_every_waiting_tick_in_order() -> void:
	_give(&"farmer", &"growth", 2)
	GameState.profile.training_due = 6
	var rank_ups: Array[RankUp] = TrainingSystem.train_due(GameState.profile, _balance)
	assert_eq(rank_ups.size(), 2)
	assert_eq(rank_ups[0].rank_after, TrainingSystem.ADEPT)
	assert_eq(rank_ups[1].rank_after, TrainingSystem.MASTER)


func test_progress_text_shows_points_toward_the_next_rank() -> void:
	var farmer: VillagerState = _give(&"farmer", &"growth")
	assert_eq(TrainingSystem.progress_text(farmer, _balance), "Novice 0/3")
	farmer.training_points = 4
	assert_eq(TrainingSystem.progress_text(farmer, _balance), "Adept 4/7")
	farmer.training_points = 9
	assert_eq(TrainingSystem.progress_text(farmer, _balance), "Master")
	assert_eq(TrainingSystem.progress_text(_village().find(&"smith"), _balance), "")


func test_preview_does_not_change_the_village() -> void:
	var farmer: VillagerState = _give(&"farmer", &"growth", 3)
	var preview: Array[RankUp] = TrainingSystem.preview(_village(), _balance, 1)
	assert_eq(preview.size(), 1)
	assert_eq(preview[0].training_points, 3)
	assert_true(preview[0].is_rank_up())
	assert_eq(farmer.training_points, 2)


func test_every_run_leaves_a_training_tick_win_or_lose() -> void:
	var region: RegionData = ContentDB.get_item(&"regions", &"mossy_hollow") as RegionData
	var profile: ProfileState = ProfileState.new()
	RunEnd.finish(RunState.start(region, 5), profile, true, _balance)
	RunEnd.finish(RunState.start(region, 6), profile, false, _balance)
	assert_eq(profile.training_due, 2)


func test_training_due_and_renown_seen_survive_a_save() -> void:
	GameState.profile.training_due = 2
	_village().renown_seen = 2
	var loaded: ProfileState = ProfileState.from_dict(JSON.parse_string(JSON.stringify(GameState.profile.to_dict())))
	assert_eq(loaded.training_due, 2)
	assert_eq(loaded.village.renown_seen, 2)


# --- RenownSystem ----------------------------------------------------------------------

func test_renown_levels_follow_the_gdd_table() -> void:
	assert_eq(_balance.renown_levels, [0, 4, 9, 15, 22, 30, 39, 49, 60, 72] as Array[int])
	assert_eq(RenownSystem.level_for(0, _balance), 1)
	assert_eq(RenownSystem.level_for(3, _balance), 1)
	assert_eq(RenownSystem.level_for(4, _balance), 2)
	assert_eq(RenownSystem.level_for(9, _balance), 3)
	assert_eq(RenownSystem.level_for(100, _balance), 10)
	assert_eq(RenownSystem.next_level_points(1, _balance), 4)
	assert_eq(RenownSystem.next_level_points(10, _balance), -1)


func test_renown_is_1_per_gift_and_2_more_per_master() -> void:
	assert_eq(RenownSystem.points(_village(), _balance), 0)
	_give(&"farmer", &"growth")
	var smith: VillagerState = _give(&"smith", &"fire")
	assert_eq(RenownSystem.points(_village(), _balance), 2)
	smith.training_points = _balance.master_tp
	assert_eq(RenownSystem.points(_village(), _balance), 4)
	assert_eq(RenownSystem.level(_village(), _balance), 2)
	assert_eq(RenownSystem.text(_village(), _balance), "Renown 2 (4/9)")


func test_the_healer_arrives_at_renown_2() -> void:
	var healer: VillagerData = ContentDB.get_item(&"villagers", &"healer") as VillagerData
	assert_eq(RenownSystem.arrivals_at(2, GameState.roster()), [healer] as Array[VillagerData])
	assert_null(_village().find(&"healer"))
	_give(&"farmer", &"growth")
	_give(&"smith", &"fire")
	_give(&"guard", &"stone", 5)
	assert_eq(GameState.admit_villagers().size(), 0, "3 points is still Renown 1")
	_village().find(&"guard").training_points = _balance.master_tp
	var arrived: Array[VillagerState] = GameState.admit_villagers()
	assert_eq(arrived.size(), 1, "a Master makes Renown 2")
	assert_eq(arrived[0].villager_id, &"healer")


# --- Village ---------------------------------------------------------------------------

func test_the_village_trains_on_return_and_plays_a_rank_up() -> void:
	watch_signals(EventBus)
	var farmer: VillagerState = _give(&"farmer", &"growth", 3)
	GameState.profile.training_due = 1
	var scene: Village = await _open()
	assert_eq(farmer.training_points, 3)
	assert_eq(GameState.profile.training_due, 0)
	assert_signal_emitted_with_parameters(EventBus, "villager_ranked_up", [_village().index_of(&"farmer"), TrainingSystem.ADEPT])
	var moment: VillageMoment = scene.moment
	assert_not_null(moment, "the rank-up plays")
	assert_eq((moment.find_child("Title", true, false) as Label).text, "Tilly is now Adept!")
	assert_true((moment.find_child("Detail", true, false) as Label).text.begins_with("Adept: "))
	assert_eq(scene.camera.target, moment.focus)
	assert_false(scene.hero.is_physics_processing(), "the hero stands still")
	var tilly: Villager = scene.villager_node(&"farmer")
	assert_eq(tilly.rank_blend, 0.0, "the star has not grown in yet")
	assert_false(moment.skip(), "the burst plays first")
	moment.step(VillageMoment.BURST_AT + VillageMoment.REVEAL_TIME)
	assert_eq(tilly.rank_blend, 1.0)
	assert_eq(tilly.progress, "Adept 3/7")
	assert_true(moment.skip())
	assert_null(scene.moment)
	assert_eq(scene.camera.target, scene.hero)
	assert_eq(scene.sign_label.text, "Tilly is now Adept!")
	await wait_physics_frames(1)
	assert_true(scene.hero.is_physics_processing(), "the hero walks again")


func test_no_training_while_a_power_waits_at_the_shrine() -> void:
	var farmer: VillagerState = _give(&"farmer", &"growth")
	GameState.profile.training_due = 1
	GameState.hero_state(0).power_offer = [&"fire"] as Array[StringName]
	var scene: Village = await _open()
	assert_eq(farmer.training_points, 0, "the tick waits for the Choice")
	assert_null(scene.moment)
	scene.use_spot(scene.gate, scene.hero)
	assert_null(GameState.run, "the gate waits too")
	assert_eq(scene.sign_label.text, "A power waits at the Shrine. Settle it before you set out.")


func test_a_power_given_after_a_run_trains_with_that_run() -> void:
	GameState.profile.training_due = 1
	GameState.profile.ceremonies_seen = 1
	_give(&"smith", &"fire", 3)
	SceneRouter.context = {"player_id": 0, "from": "shrine",
			"ceremony": {"villager_id": &"smith", "power_id": &"fire", "first_gift": false}}
	var scene: Village = await _open()
	assert_eq(_village().find(&"smith").training_points, 2, "no tick during the ceremony")
	scene.ceremony.skip()
	assert_eq(_village().find(&"smith").training_points, 3, "the tick follows the ceremony")
	assert_not_null(scene.moment, "and Brann reaches Adept on screen")


func test_a_new_renown_level_moves_the_healer_in_on_screen() -> void:
	_give(&"farmer", &"growth")
	_give(&"smith", &"fire")
	_give(&"guard", &"stone", 7)
	GameState.profile.training_due = 1
	var scene: Village = await _open()
	assert_not_null(_village().find(&"healer"), "the Guard's Master made Renown 2")
	assert_eq(_village().renown_seen, 2)
	var healer: Villager = scene.villager_node(&"healer")
	assert_not_null(healer)
	assert_eq((scene.moment.find_child("Title", true, false) as Label).text, "Maren is now Master!")
	assert_eq(healer.modulate.a, 0.0, "the Healer waits for their moment")
	scene.moment.step(VillageMoment.DURATION)
	var moment: VillageMoment = scene.moment
	assert_not_null(moment, "the Renown moment follows")
	assert_eq((moment.find_child("Title", true, false) as Label).text, "Renown 2!")
	assert_eq(moment.villager, healer)
	moment.step(VillageMoment.DURATION)
	assert_null(scene.moment)
	assert_eq(healer.modulate.a, 1.0)
	assert_eq((scene.get_node("Overlay/Renown") as Label).text, "Renown 2 (5/9)")


func test_the_board_names_the_next_arrival() -> void:
	_give(&"farmer", &"growth")
	var scene: Village = await _open()
	var text: String = scene.board_text()
	assert_true(text.begins_with("Renown 1 (1/4). At Renown 2, "), text)
	assert_true(text.contains("the Healer moves in"), text)


func test_rank_props_show_on_the_villager_and_house() -> void:
	_give(&"farmer", &"growth", 8)
	var scene: Village = await _open()
	var farmer: Villager = scene.villager_node(&"farmer")
	var plot: VillagePlot = scene.plots.get_child(_village().find(&"farmer").plot) as VillagePlot
	assert_eq(farmer.rank, TrainingSystem.MASTER)
	assert_eq(plot.rank, TrainingSystem.MASTER)
	assert_eq(farmer.progress, "Master")


# --- Results ---------------------------------------------------------------------------

func test_results_preview_the_training_tick() -> void:
	_give(&"farmer", &"growth", 3)
	_give(&"smith", &"fire")
	GameState.profile.training_due = 1
	SceneRouter.context = {"summary": RunSummary.new()}
	var screen: ResultsScreen = RESULTS_SCENE.instantiate()
	add_child_autofree(screen)
	await wait_process_frames(1)
	assert_eq((screen.find_child("Training", true, false) as Label).text, "Training: Brann 1/3, Tilly reaches Adept")
