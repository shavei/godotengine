extends GutTest
## The village (M4 PR 1): villager and combo content, VillageState arrivals and saving,
## and the village scene (villagers on plots, Shrine, gate, talking, gifts shown).

const VILLAGE_SCENE: PackedScene = preload("res://scenes/village/village.tscn")
const PROTOTYPE_VILLAGERS: Array[StringName] = [&"smith", &"farmer", &"guard", &"healer"]

var _original_profile: ProfileState
var _original_context: Dictionary


func before_each() -> void:
	_original_profile = GameState.profile
	_original_context = SceneRouter.context
	GameState.new_profile()


func after_each() -> void:
	GameState.profile = _original_profile
	SceneRouter.context = _original_context
	GameState.run = null


func _roster() -> Array[VillagerData]:
	var roster: Array[VillagerData] = []
	for item: Resource in ContentDB.get_all(&"villagers"):
		roster.append(item as VillagerData)
	return roster


# --- Content --------------------------------------------------------------------

func test_prototype_villagers_exist_with_base_services() -> void:
	for id: StringName in PROTOTYPE_VILLAGERS:
		var data: VillagerData = ContentDB.get_item(&"villagers", id) as VillagerData
		assert_not_null(data, "villager %s" % id)
		if data == null:
			continue
		assert_false(data.display_name.is_empty())
		assert_false(data.workplace.is_empty())
		assert_not_null(data.base_service, "%s has a base service" % id)
		assert_false(data.greeting.is_empty())
		assert_between(data.home_plot, 0, VillageState.START_PLOTS - 1)


func test_every_villager_and_power_pair_has_one_combo() -> void:
	var powers: Array[Resource] = ContentDB.get_all(&"powers")
	for villager: Resource in ContentDB.get_all(&"villagers"):
		for power: Resource in powers:
			var id: StringName = ComboData.id_for(villager.get("id"), power.get("id"))
			var combo: ComboData = ContentDB.get_item(&"combos", id) as ComboData
			assert_not_null(combo, "combo %s" % id)
			if combo == null:
				continue
			assert_eq(combo.villager_id, villager.get("id"))
			assert_eq(combo.power_id, power.get("id"))
			assert_not_null(combo.novice, "%s Novice service" % id)
			assert_not_null(combo.adept, "%s Adept service" % id)
			assert_false(combo.technique_name.is_empty(), "%s Technique" % id)
			assert_false(combo.gift_line.is_empty(), "%s gift line" % id)
	assert_eq(ContentDB.count(&"combos"), ContentDB.count(&"villagers") * powers.size(), "no stray combos")


func test_content_text_has_no_em_dash() -> void:
	for category: StringName in [&"villagers", &"combos"]:
		for item: Resource in ContentDB.get_all(category):
			var text: String = var_to_str(item)
			for sub: Resource in [item.get("novice"), item.get("adept"), item.get("base_service")]:
				if sub != null:
					text += (sub as ServiceData).description
			assert_false(text.contains(char(0x2014)), "%s has an em dash" % item.get("id"))


# --- VillageState --------------------------------------------------------------------

func test_a_new_profile_moves_in_the_prototype_villagers_on_their_home_plots() -> void:
	var village: VillageState = GameState.profile.village
	assert_eq(village.villagers.size(), 4)
	for id: StringName in PROTOTYPE_VILLAGERS:
		var state: VillagerState = village.find(id)
		assert_not_null(state, "%s lives in the village" % id)
		var data: VillagerData = ContentDB.get_item(&"villagers", id) as VillagerData
		assert_eq(state.plot, data.home_plot)
		assert_false(state.has_power())


func test_admit_respects_renown_and_does_not_duplicate() -> void:
	var village: VillageState = VillageState.new()
	var arrived: Array[VillagerState] = village.admit(_roster(), 1)
	assert_eq(arrived.size(), 3, "the Healer arrives at Renown 2")
	assert_null(village.find(&"healer"))
	arrived = village.admit(_roster(), 2)
	assert_eq(arrived.size(), 1)
	assert_eq(arrived[0].villager_id, &"healer")
	assert_eq(village.admit(_roster(), 2).size(), 0, "nobody moves in twice")


func test_a_taken_home_plot_sends_the_newcomer_to_a_free_one() -> void:
	var village: VillageState = VillageState.new()
	var smith: VillagerData = ContentDB.get_item(&"villagers", &"smith") as VillagerData
	village.villagers.append(VillagerState.create(&"someone", smith.home_plot))
	village.admit([smith] as Array[VillagerData], 1)
	var placed: VillagerState = village.find(&"smith")
	assert_ne(placed.plot, smith.home_plot)
	assert_eq(village.on_plot(placed.plot), placed)


func test_the_village_survives_a_save_round_trip() -> void:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(&"farmer"), &"growth", 4)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.profile.to_dict()))
	var loaded: ProfileState = ProfileState.from_dict(data)
	assert_eq(loaded.village.villagers.size(), 4)
	var farmer: VillagerState = loaded.village.find(&"farmer")
	assert_eq(farmer.power_id, &"growth")
	assert_eq(farmer.training_points, 3)
	assert_eq(farmer.plot, village.find(&"farmer").plot)
	assert_eq(loaded.village.plot_count, VillageState.START_PLOTS)


func test_old_saves_without_a_village_get_the_starting_villagers() -> void:
	var original_dir: String = SaveManager.save_dir
	SaveManager.save_dir = "user://test_saves_village"
	SaveManager.save_data(GameState.slot, {"run_count": 3, "heroes": {"0": {"level": 2}}})
	GameState.load_profile()
	assert_eq(GameState.profile.run_count, 3)
	assert_eq(GameState.profile.village.villagers.size(), 4)
	SaveManager.delete_slot(GameState.slot)
	SaveManager.save_dir = original_dir


# --- Village scene --------------------------------------------------------------------

func _open() -> Village:
	var village: Village = VILLAGE_SCENE.instantiate()
	add_child_autofree(village)
	await wait_physics_frames(2)
	return village


func test_villagers_stand_at_their_plots() -> void:
	var scene: Village = await _open()
	assert_eq(scene.villagers.size(), 4)
	for villager: Villager in scene.villagers:
		var plot: VillagePlot = scene.plots.get_child(villager.state.plot) as VillagePlot
		assert_eq(plot.index, villager.state.plot)
		assert_eq(villager.position, plot.position)
		assert_true(plot.occupied)
	var empty: int = 0
	for plot: VillagePlot in scene.plots.get_children():
		if not plot.occupied:
			empty += 1
	assert_eq(empty, 2, "6 plots, 4 villagers")


func test_a_gift_shows_on_the_villager_and_their_house() -> void:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(&"smith"), &"fire")
	var scene: Village = await _open()
	var fire: PowerData = ContentDB.get_item(&"powers", &"fire") as PowerData
	var smith: Villager = scene.find_child("VillagerSmith", true, false) as Villager
	assert_not_null(smith)
	assert_eq(smith.power, fire)
	assert_eq(smith.rank, TrainingSystem.NOVICE)
	var plot: VillagePlot = scene.plots.get_child(village.find(&"smith").plot) as VillagePlot
	assert_eq(plot.power_color, fire.color, "the roof is trimmed in the power's color")
	var farmer_plot: VillagePlot = scene.plots.get_child(village.find(&"farmer").plot) as VillagePlot
	assert_eq(farmer_plot.power_color, Color.TRANSPARENT)


func test_talking_tells_the_service() -> void:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(&"farmer"), &"growth", 5)
	var scene: Village = await _open()
	var smith: Villager = scene.find_child("VillagerSmith", true, false) as Villager
	scene.talk(smith)
	assert_true(scene.sign_label.text.begins_with("Brann the Smith: \"Every blade"))
	assert_true(scene.sign_label.text.contains("Sells weapons"))
	var farmer: Villager = scene.find_child("VillagerFarmer", true, false) as Villager
	var text: String = scene.speech(farmer)
	assert_true(text.begins_with("Tilly the Farmer (Growth, Adept)"), text)
	assert_true(text.contains("+2 flasks"), "Novice service")
	assert_true(text.contains("Adept: +3 flasks"), "a level 5 gift is Adept at once")


func test_the_shrine_glows_while_a_power_waits() -> void:
	var scene: Village = await _open()
	assert_eq(scene.shrine.caption, "Shrine")
	assert_eq(scene.sign_label.text, "Welcome home to Emberwick.")
	scene.free()
	GameState.hero_state(0).power_offer = [&"frost"] as Array[StringName]
	scene = await _open()
	assert_eq(scene.shrine.caption, "Shrine: a power waits")
	assert_eq(scene.shrine.icon_shape, (ContentDB.get_item(&"powers", &"frost") as PowerData).icon_shape)
	assert_eq(scene.sign_label.text, "A power waits at the Shrine.")


func test_the_gate_starts_a_run_or_continues_the_saved_one() -> void:
	var original_dir: String = SaveManager.save_dir
	SaveManager.save_dir = "user://test_saves_village"
	var scene: Village = await _open()
	assert_eq(scene.gate.caption, "Gate: Mossy Hollow")
	watch_signals(EventBus)
	scene.prepare_run()
	assert_not_null(GameState.run, "a run is in progress")
	assert_eq(GameState.run.region.id, &"mossy_hollow")
	assert_signal_emitted(EventBus, "run_started")
	GameState.run.floor_index = 1
	GameState.save_run()
	GameState.run = null
	scene.refresh()
	assert_eq(scene.gate.caption, "Gate: continue your run")
	scene.prepare_run()
	assert_eq(GameState.run.floor_index, 1, "the saved run goes on")
	assert_signal_emit_count(EventBus, "run_started", 1)
	SaveManager.delete_slot(GameState.slot)
	SaveManager.save_dir = original_dir
