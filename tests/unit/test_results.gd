extends GutTest
## The results screen shows the run's XP, mastery, loot and village income, and points to
## the Shrine for spending (GrowthPanel, tested in test_growth_panel.gd).

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


func test_points_and_shards_are_spent_at_the_shrine() -> void:
	var hero: HeroState = GameState.hero_state(0)
	hero.attribute_points = 3
	var screen: ResultsScreen = await _open(_make_summary(true))
	assert_eq(_text(screen, "Points"), "3 attribute points to spend at the Shrine")
	assert_null(screen.find_child("MightButton", true, false), "no spending here any more")
	assert_eq(_text(screen, "Shards"), "Power Shards: 0")
	assert_true(screen.find_child("ContinueButton", true, false).has_focus())
	screen.queue_free()
	var balance: BalanceData = ContentDB.get_item(&"balance", &"default") as BalanceData
	GiftSystem.keep(hero, &"fire", balance)
	hero.bank.add(Wallet.SHARDS, 4)
	hero.attribute_points = 0
	screen = await _open(_make_summary(true))
	assert_true(_text(screen, "Points").begins_with("Level 1 hero"))
	assert_eq(_text(screen, "Shards"), "Power Shards: 4. The Shrine can level up a kept power.")


func test_village_income_is_listed() -> void:
	var summary: RunSummary = _make_summary(false)
	var screen: ResultsScreen = await _open(summary)
	assert_eq(_text(screen, "Income"), "", "no income, no line")
	screen.queue_free()
	summary.income = {Wallet.COINS: 40, Wallet.WOOD: 10}
	screen = await _open(summary)
	assert_eq(_text(screen, "Income"), "From the village: +40 Coins, +10 Wood")


func test_continue_leads_back_to_the_village() -> void:
	var screen: ResultsScreen = await _open(_make_summary(true))
	assert_eq(screen.next_scene(), ResultsScreen.VILLAGE_SCENE)
	assert_eq((screen.find_child("ContinueButton", true, false) as Button).text, "Back to the village")
	screen.queue_free()
	GameState.hero_state(0).power_offer = [&"fire", &"frost"] as Array[StringName]
	screen = await _open(_make_summary(true))
	assert_eq(screen.next_scene(), ResultsScreen.VILLAGE_SCENE, "the Shrine opens the Choice")
	assert_eq((screen.find_child("ContinueButton", true, false) as Button).text, "Back to the village: a power waits")
