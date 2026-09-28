extends GutTest
## The Shrine's Grow stronger panel (M4 PR 2): spends attribute points and Power Shards,
## and resets attributes for coins after a second press.

var _original_profile: ProfileState
var _balance: BalanceData


func before_each() -> void:
	_original_profile = GameState.profile
	GameState.new_profile()
	_balance = ContentDB.get_item(&"balance", &"default") as BalanceData


func after_each() -> void:
	GameState.profile = _original_profile


func _open() -> GrowthPanel:
	var panel: GrowthPanel = GrowthPanel.new()
	panel.setup(0, _balance)
	panel.save_on_spend = false
	add_child_autofree(panel)
	await wait_process_frames(1)
	return panel


func _text(panel: GrowthPanel, node_name: String) -> String:
	return (panel.find_child(node_name, true, false) as Label).text


func test_points_can_be_spent_on_might_vigor_and_focus() -> void:
	GameState.hero_state(0).attribute_points = 3
	var panel: GrowthPanel = await _open()
	var might: Button = panel.find_child("MightButton", true, false)
	var focus: Button = panel.find_child("FocusButton", true, false)
	assert_eq(panel.default_focus(), might, "points to spend come first")
	assert_eq(_text(panel, "Points"), "3 attribute points to spend")
	watch_signals(panel)
	might.pressed.emit()
	focus.pressed.emit()
	assert_signal_emit_count(panel, "changed", 2)
	assert_eq(GameState.hero_state(0).attribute(HeroState.MIGHT), 1)
	assert_eq(GameState.hero_state(0).attribute(HeroState.FOCUS), 1)
	assert_eq(_text(panel, "Points"), "1 attribute point to spend")
	panel.spend(HeroState.VIGOR)
	assert_eq(GameState.hero_state(0).attribute_points, 0)
	assert_true(might.disabled, "no points left")
	assert_true(_text(panel, "Points").begins_with("Level 1 hero"))
	assert_null(panel.default_focus(), "nothing left to spend")


func test_banked_shards_level_up_a_kept_power() -> void:
	var hero: HeroState = GameState.hero_state(0)
	GiftSystem.keep(hero, &"fire", _balance)
	GiftSystem.keep(hero, &"stone", _balance)
	hero.bank.add(Wallet.SHARDS, 9)
	watch_signals(EventBus)
	var panel: GrowthPanel = await _open()
	var fire: Button = panel.find_child("FireLevelButton", true, false)
	var stone: Button = panel.find_child("StoneLevelButton", true, false)
	assert_eq(panel.default_focus(), fire, "with no points, a power to level comes first")
	assert_eq(fire.text, "Fire level 1 > 2\n3 shards")
	assert_eq(_text(panel, "Shards"), "Power Shards: 9. Spend them to level up a kept power.")
	fire.pressed.emit()
	assert_eq(GiftSystem.find(hero, &"fire").level, 2)
	assert_eq(hero.bank.amount(Wallet.SHARDS), 6)
	assert_signal_emitted_with_parameters(EventBus, "power_leveled", [0, &"fire", 2])
	assert_eq(fire.text, "Fire level 2 > 3\n5 shards")
	assert_eq(_text(panel, "PowerNote"), "Ember Bolt level 3: Explodes on impact (small area).")
	fire.pressed.emit()
	assert_eq(hero.bank.amount(Wallet.SHARDS), 1)
	assert_true(fire.disabled, "level 4 costs 8")
	assert_true(stone.disabled, "1 shard is not enough for Stone either")


func test_no_kept_powers_says_so() -> void:
	GameState.hero_state(0).bank.add(Wallet.SHARDS, 4)
	var panel: GrowthPanel = await _open()
	assert_eq(_text(panel, "Shards"), "No kept powers yet. Power Shards: 4")


func test_respec_costs_coins_and_needs_a_second_press() -> void:
	var hero: HeroState = GameState.hero_state(0)
	hero.level = 3
	hero.attributes[HeroState.MIGHT] = 2
	hero.attributes[HeroState.FOCUS] = 1
	var panel: GrowthPanel = await _open()
	var respec: Button = panel.find_child("RespecButton", true, false)
	assert_true(respec.disabled, "150 coins needed, none banked")
	assert_eq(respec.text, "Reset attributes: 150 coins (you have 0)")
	hero.bank.add(Wallet.COINS, 200)
	panel.refresh()
	assert_false(respec.disabled)
	respec.pressed.emit()
	assert_eq(hero.attribute(HeroState.MIGHT), 2, "the first press only asks")
	assert_true(respec.text.begins_with("Sure?"))
	respec.pressed.emit()
	assert_eq(hero.attribute(HeroState.MIGHT), 0)
	assert_eq(hero.attribute(HeroState.FOCUS), 0)
	assert_eq(hero.attribute_points, 3)
	assert_eq(hero.bank.amount(Wallet.COINS), 50)
	assert_true(respec.disabled, "nothing spent to reset now")


func test_has_anything_to_spend() -> void:
	var hero: HeroState = GameState.hero_state(0)
	assert_false(GrowthPanel.has_anything_to_spend(hero, _balance))
	hero.attribute_points = 1
	assert_true(GrowthPanel.has_anything_to_spend(hero, _balance))
	hero.attribute_points = 0
	GiftSystem.keep(hero, &"frost", _balance)
	hero.bank.add(Wallet.SHARDS, 2)
	assert_false(GrowthPanel.has_anything_to_spend(hero, _balance), "level 2 costs 3")
	hero.bank.add(Wallet.SHARDS, 1)
	assert_true(GrowthPanel.has_anything_to_spend(hero, _balance))
