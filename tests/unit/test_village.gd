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
	SceneRouter.context = {}
	GameState.new_profile()
	# The Healer moves in at Renown 2.
	GameState.admit_villagers(2)
	# Past the forced first gift (its tests set this back).
	GameState.profile.first_gift_done = true


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
			assert_not_null(combo.technique, "%s Technique" % id)
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

func test_a_new_profile_moves_in_the_starting_villagers_on_their_home_plots() -> void:
	GameState.new_profile()
	var village: VillageState = GameState.profile.village
	assert_eq(village.villagers.size(), 3, "the Healer waits for Renown 2")
	assert_null(village.find(&"healer"))
	for id: StringName in [&"smith", &"farmer", &"guard"] as Array[StringName]:
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
	assert_eq(GameState.profile.village.villagers.size(), 3, "the Healer waits for Renown 2")
	assert_eq(GameState.profile.village.renown_seen, 1, "an old save takes its Renown as seen")
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
	assert_true(text.begins_with("Tilly the Farmer (Growth, Adept 4/7)"), text)
	assert_true(text.contains("+2 flasks"), "Novice service")
	assert_true(text.contains("Adept: +3 flasks"), "a level 5 gift is Adept at once")



func test_walking_off_a_villager_brings_back_the_welcome_line() -> void:
	var scene: Village = await _open()
	var farmer: Villager = scene.find_child("VillagerFarmer", true, false) as Villager
	scene.hero.global_position = farmer.spot.global_position
	await wait_physics_frames(3)
	assert_true(farmer.spot.is_occupied())
	assert_eq(farmer.name_position(), Villager.NAME_ABOVE, "the hero would cover a name at the feet")
	scene.talk(farmer)
	assert_true(scene.sign_label.text.begins_with("Tilly the Farmer"))
	scene.hero.global_position = farmer.spot.global_position + Vector2(0, 80)
	await wait_physics_frames(3)
	assert_false(farmer.spot.is_occupied())
	assert_eq(farmer.name_position(), Villager.NAME_BELOW)
	assert_eq(scene.sign_label.text, "Welcome home to Emberwick.")


func test_the_hero_never_runs_out_of_stamina_in_the_village() -> void:
	var scene: Village = await _open()
	assert_true(scene.hero.stamina.unlimited, "no stamina bar shows in the village, so there is no limit")
	for i: int in 10:
		assert_true(scene.hero.stamina.try_spend(scene.balance.dodge_stamina_cost))


func test_the_sign_and_help_lines_never_cover_walkable_ground() -> void:
	var scene: Village = await _open()
	var sign_top: float = scene.camera.limit_bottom + scene.sign_label.offset_top
	assert_eq(scene.camera.limit_bottom, int(scene.room.get_rect().end.y) + Village.HUD_BAND)
	assert_true(sign_top >= scene.room.get_inner_rect().end.y, "a 3-line sign ends above the floor's bottom edge")


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
	assert_true(scene.gate.caption_above, "the sign and help lines would cover a caption below the gate")
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


# --- Shops (M4 PR 2) ---------------------------------------------------------------

func test_talking_to_the_smith_opens_the_forge_and_steel_can_be_bought() -> void:
	GameState.hero_state(0).bank.add(Wallet.COINS, 320)
	var scene: Village = await _open()
	var smith: Villager = scene.find_child("VillagerSmith", true, false) as Villager
	scene.talk(smith)
	var shop: ShopPanel = scene.shop
	assert_not_null(shop, "the Smith sells weapon tiers")
	shop.save_on_buy = false
	await wait_process_frames(1)
	assert_false(scene.hero.is_physics_processing(), "the hero waits while shopping")
	var tier: Button = shop.find_child("TierButton", true, false)
	assert_true(tier.text.begins_with("Steel Sword: x1.3 damage (now Iron)"), tier.text)
	assert_false(tier.disabled)
	assert_true(tier.has_focus())
	assert_null(shop.find_child("ServiceButton", true, false), "no power, no infusion")
	tier.pressed.emit()
	assert_eq(GameState.hero_state(0).weapon_tier(&"sword"), 1)
	assert_eq(GameState.hero_state(0).bank.amount(Wallet.COINS), 20)
	assert_almost_eq(scene.hero.stats.weapon_tier, 1.3, 0.001, "the hero carries Steel at once")
	assert_true(tier.disabled, "Runed needs Forge level 3")
	assert_true(tier.text.ends_with("Runed needs Forge level 3."), tier.text)
	shop.close()
	await wait_physics_frames(2)
	assert_null(scene.shop)
	assert_true(scene.hero.is_physics_processing())



func test_gamepad_b_closes_the_forge() -> void:
	var scene: Village = await _open()
	scene.talk(scene.find_child("VillagerSmith", true, false) as Villager)
	await wait_process_frames(1)
	assert_not_null(scene.shop)
	var press: InputEventJoypadButton = InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_B
	press.pressed = true
	get_viewport().push_input(press)
	await wait_process_frames(1)
	assert_null(scene.shop, "B backs out of a menu, like Escape")


func test_a_smith_with_a_power_sells_the_infusion_once() -> void:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(&"smith"), &"fire")
	GameState.hero_state(0).bank.add(Wallet.COINS, 150)
	var scene: Village = await _open()
	scene.talk(scene.find_child("VillagerSmith", true, false) as Villager)
	var shop: ShopPanel = scene.shop
	shop.save_on_buy = false
	await wait_process_frames(1)
	var service: Button = shop.find_child("ServiceButton", true, false)
	assert_true(service.text.begins_with("Sells a Fire infusion: weapon hits Burn 15%"), service.text)
	assert_true(service.has_focus(), "Steel costs more than the hero has")
	assert_true(shop.buy_service())
	assert_true(GameState.hero_state(0).has_bought(&"smith_fire"))
	assert_true(service.disabled)
	assert_true(service.text.ends_with("Yours already."))
	assert_false(shop.buy_service(), "once only")


func test_villagers_with_nothing_to_sell_only_talk() -> void:
	var scene: Village = await _open()
	var farmer: Villager = scene.find_child("VillagerFarmer", true, false) as Villager
	scene.talk(farmer)
	assert_null(scene.shop)
	assert_true(scene.sign_label.text.contains("+1 flask charge every run."))
	var guard: Villager = scene.find_child("VillagerGuard", true, false) as Villager
	assert_true(scene.speech(guard).contains("Raids have not started yet."))


func test_the_shrine_says_when_there_is_something_to_spend() -> void:
	GameState.hero_state(0).attribute_points = 1
	var scene: Village = await _open()
	assert_eq(scene.shrine.caption, "Shrine: grow stronger")


# --- The gift ceremony and the first gift (M4 PR 3) ----------------------------------

func _open_after_gift(villager_id: StringName, power_id: StringName, first_gift: bool = false) -> Village:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(villager_id), power_id)
	SceneRouter.context = {"player_id": 0, "from": "shrine",
			"ceremony": {"villager_id": villager_id, "power_id": power_id, "first_gift": first_gift}}
	var scene: Village = VILLAGE_SCENE.instantiate()
	scene.save_on_change = false
	add_child_autofree(scene)
	await wait_physics_frames(2)
	return scene


func test_leaving_the_shrine_puts_the_hero_below_it() -> void:
	SceneRouter.context = {"from": "shrine"}
	var scene: Village = await _open()
	assert_eq(scene.hero.position, scene.get_node("Spots/Shrine").position + Village.SHRINE_STEP)
	assert_null(scene.ceremony, "no gift, no ceremony")


func test_a_gift_plays_its_ceremony() -> void:
	watch_signals(EventBus)
	var scene: Village = await _open_after_gift(&"smith", &"fire")
	var ceremony: GiftCeremony = scene.ceremony
	assert_not_null(ceremony)
	var smith: Villager = scene.villager_node(&"smith")
	var plot: VillagePlot = scene.plots.get_child(GameState.profile.village.find(&"smith").plot) as VillagePlot
	assert_eq(smith.gift_blend, 0.0, "the villager still wears their old colors")
	assert_eq(plot.trim_blend, 0.0)
	assert_eq(scene.camera.target, ceremony.focus, "the camera follows the Spark")
	assert_false(scene.hero.is_physics_processing(), "the hero stands still")
	assert_false(scene.get_node("Overlay").visible, "the sign waits under the bars")
	assert_eq((ceremony.find_child("Title", true, false) as Label).text, "Fire for Brann the Smith")
	assert_true((ceremony.find_child("Line", true, false) as Label).text.begins_with("\""))
	assert_eq((ceremony.find_child("Service", true, false) as Label).text,
			"New service: Sells a Fire infusion: weapon hits Burn 15% of the time. Buy it once at the Forge for 100 coins.")
	scene.use_spot(scene.gate, scene.hero)
	assert_null(GameState.run, "the gate waits until the ceremony ends")
	var start: Vector2 = ceremony.spark_position()
	ceremony.step(CeremonyTimeline.FLY_AT + 0.5)
	assert_ne(ceremony.spark_position(), start, "the Spark flies")
	assert_false(ceremony.find_child("Dialogue", true, false).visible, "the line comes after the burst")
	ceremony.step(CeremonyTimeline.BURST_AT + CeremonyTimeline.SWAP_TIME)
	assert_eq(smith.gift_blend, 1.0, "the palette swap is done")
	assert_eq(plot.trim_blend, 1.0, "the roof is trimmed")
	assert_true(ceremony.find_child("Dialogue", true, false).visible)
	ceremony.step(CeremonyTimeline.DURATION)
	assert_null(scene.ceremony, "it ends on its own")
	assert_eq(GameState.profile.ceremonies_seen, 1)
	assert_signal_emitted_with_parameters(EventBus, "gift_ceremony_finished", [GameState.profile.village.index_of(&"smith")])
	assert_eq(scene.camera.target, scene.hero)
	assert_true(scene.get_node("Overlay").visible)
	assert_eq(scene.sign_label.text, "Brann the Smith holds Fire now.")
	await wait_physics_frames(1)
	assert_true(scene.hero.is_physics_processing(), "the hero walks again")


func test_the_first_ceremony_cannot_be_skipped_until_the_line_is_read() -> void:
	var scene: Village = await _open_after_gift(&"farmer", &"growth", true)
	var ceremony: GiftCeremony = scene.ceremony
	assert_false(ceremony.skip())
	ceremony.step(CeremonyTimeline.LINE_AT)
	assert_false(ceremony.skip(), "the line has only just appeared")
	ceremony.step(CeremonyTimeline.FIRST_READ_TIME)
	assert_true(ceremony.skip())
	assert_null(scene.ceremony)
	assert_eq(scene.villager_node(&"farmer").gift_blend, 1.0, "skipping still leaves the new colors")
	assert_true(scene.sign_label.text.begins_with("The Elder: \"Well done."), scene.sign_label.text)


func test_later_ceremonies_skip_at_once() -> void:
	GameState.profile.ceremonies_seen = 1
	var scene: Village = await _open_after_gift(&"healer", &"frost")
	var press: InputEventAction = InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	scene.ceremony._unhandled_input(press)
	assert_null(scene.ceremony)
	assert_eq(GameState.profile.ceremonies_seen, 2)


func test_the_elder_points_to_the_shrine_before_the_first_gift() -> void:
	GameState.profile.first_gift_done = false
	GameState.hero_state(0).power_offer = [&"growth"] as Array[StringName]
	var scene: Village = await _open()
	assert_eq(scene.shrine.caption, "Shrine: your first Spark waits")
	assert_eq(scene.sign_label.text, "The Elder: \"Your first Spark! Bring it to the Shrine. Tilly could use it.\"")


func test_a_gifted_villager_wears_the_power_color() -> void:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(&"guard"), &"frost")
	var scene: Village = await _open()
	var guard: Villager = scene.villager_node(&"guard")
	var frost: PowerData = ContentDB.get_item(&"powers", &"frost") as PowerData
	assert_eq(guard.body_color(), guard.data.color.lerp(frost.color, Villager.PALETTE_SHIFT))
	assert_eq(scene.villager_node(&"smith").body_color(), scene.villager_node(&"smith").data.color, "no gift, no swap")
