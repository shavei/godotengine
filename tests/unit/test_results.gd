extends GutTest
## The results screen shows the run's XP, mastery and loot, and spends attribute points.

const RESULTS_SCENE: PackedScene = preload("res://scenes/ui/results.tscn")

var _original_profile: ProfileState
var _original_context: Dictionary


func before_each() -> void:
	_original_profile = GameState.profile
	_original_context = SceneRouter.context
	GameState.new_profile()


func after_each() -> void:
	GameState.profile = _original_profile
	SceneRouter.context = _original_context


func _make_summary(success: bool) -> RunSummary:
	var summary: RunSummary = RunSummary.new()
	summary.success = success
	summary.region_name = "Mossy Hollow"
	summary.floor_reached = 2
	summary.rooms_cleared = 9
	summary.elapsed = 431.0
	summary.xp_gained = 170
	summary.level_before = 1
	summary.level_after = 2
	summary.xp_into_level = 29
	summary.xp_for_next = 260
	summary.weapon_id = &"sword"
	summary.mastery_xp_gained = 88
	summary.found = {Wallet.COINS: 41, Wallet.WOOD: 6}
	summary.kept = {Wallet.COINS: 41 if success else 20, Wallet.WOOD: 6 if success else 3}
	summary.keep_fraction = 1.0 if success else 0.5
	return summary


func _open(summary: RunSummary) -> ResultsScreen:
	SceneRouter.context = {"summary": summary}
	var screen: ResultsScreen = RESULTS_SCENE.instantiate()
	screen.save_on_spend = false
	add_child_autofree(screen)
	await wait_process_frames(1)
	return screen


func _text(screen: ResultsScreen, node_name: String) -> String:
	return (screen.find_child(node_name, true, false) as Label).text


func test_a_fall_shows_where_and_what_was_kept() -> void:
	var screen: ResultsScreen = await _open(_make_summary(false))
	assert_eq(_text(screen, "Headline"), "You fell on floor 2 of 3")
	assert_eq(_text(screen, "Stats"), "Time 7:11    Rooms cleared 9")
	assert_eq(_text(screen, "XpGained"), "+170 XP")
	assert_eq(_text(screen, "Level"), "Level 1 > 2. Level up!")
	assert_true(_text(screen, "LootNote").contains("50%"))
	assert_true(_text(screen, "Mastery").begins_with("Sword mastery +88 XP"))


func test_a_clear_says_so() -> void:
	var screen: ResultsScreen = await _open(_make_summary(true))
	assert_eq(_text(screen, "Headline"), "Mossy Hollow cleared!")
	assert_eq(_text(screen, "LootNote"), "Everything comes home with you.")


func test_points_can_be_spent_on_might_vigor_and_focus() -> void:
	GameState.hero_state(0).attribute_points = 3
	var screen: ResultsScreen = await _open(_make_summary(true))
	var might: Button = screen.find_child("MightButton", true, false)
	var focus: Button = screen.find_child("FocusButton", true, false)
	assert_true(might.has_focus(), "points to spend come first")
	assert_false(focus.disabled, "Focus is open now that powers exist")
	assert_eq(_text(screen, "Points"), "3 attribute points to spend")
	might.pressed.emit()
	focus.pressed.emit()
	assert_eq(GameState.hero_state(0).attribute(HeroState.MIGHT), 1)
	assert_eq(GameState.hero_state(0).attribute(HeroState.FOCUS), 1)
	assert_eq(_text(screen, "Points"), "1 attribute point to spend")
	screen.spend(HeroState.VIGOR)
	assert_eq(GameState.hero_state(0).attribute_points, 0)
	assert_true(might.disabled, "no points left")
	assert_true(_text(screen, "Points").begins_with("Level 1 hero"))


func test_without_points_continue_has_focus() -> void:
	var screen: ResultsScreen = await _open(_make_summary(true))
	assert_true(screen.find_child("ContinueButton", true, false).has_focus())


func test_banked_shards_level_up_a_kept_power() -> void:
	var hero: HeroState = GameState.hero_state(0)
	var balance: BalanceData = ContentDB.get_item(&"balance", &"default") as BalanceData
	GiftSystem.keep(hero, &"fire", balance)
	GiftSystem.keep(hero, &"stone", balance)
	hero.bank.add(Wallet.SHARDS, 9)
	watch_signals(EventBus)
	var screen: ResultsScreen = await _open(_make_summary(true))
	var fire: Button = screen.find_child("FireLevelButton", true, false)
	var stone: Button = screen.find_child("StoneLevelButton", true, false)
	assert_true(fire.has_focus(), "with no points, a power to level comes first")
	assert_eq(fire.text, "Fire level 1 > 2\n3 shards")
	assert_eq(_text(screen, "Shards"), "Power Shards: 9. Spend them to level up a kept power.")
	fire.pressed.emit()
	assert_eq(GiftSystem.find(hero, &"fire").level, 2)
	assert_eq(hero.bank.amount(Wallet.SHARDS), 6)
	assert_signal_emitted_with_parameters(EventBus, "power_leveled", [0, &"fire", 2])
	assert_eq(fire.text, "Fire level 2 > 3\n5 shards")
	assert_eq(_text(screen, "PowerNote"), "Ember Bolt level 3: Explodes on impact (small area).")
	fire.pressed.emit()
	assert_eq(hero.bank.amount(Wallet.SHARDS), 1)
	assert_true(fire.disabled, "level 4 costs 8")
	assert_true(stone.disabled, "1 shard is not enough for Stone either")


func test_no_kept_powers_says_so() -> void:
	GameState.hero_state(0).bank.add(Wallet.SHARDS, 4)
	var screen: ResultsScreen = await _open(_make_summary(true))
	assert_eq(_text(screen, "Shards"), "No kept powers yet. Power Shards: 4")
	assert_true(screen.find_child("ContinueButton", true, false).has_focus())


func test_continue_leads_back_to_the_village() -> void:
	var screen: ResultsScreen = await _open(_make_summary(true))
	assert_eq(screen.next_scene(), ResultsScreen.VILLAGE_SCENE)
	assert_eq((screen.find_child("ContinueButton", true, false) as Button).text, "Back to the village")
	screen.queue_free()
	GameState.hero_state(0).power_offer = [&"fire", &"frost"] as Array[StringName]
	screen = await _open(_make_summary(true))
	assert_eq(screen.next_scene(), ResultsScreen.VILLAGE_SCENE, "the Shrine opens the Choice")
	assert_eq((screen.find_child("ContinueButton", true, false) as Button).text, "Back to the village: a power waits")
