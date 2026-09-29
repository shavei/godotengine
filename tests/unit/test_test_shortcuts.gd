extends GutTest
## Test shortcuts (TestShortcuts rules and the TestMenu screen, debug builds only).

var _original_profile: ProfileState
var region: RegionData


func before_each() -> void:
	_original_profile = GameState.profile
	GameState.new_profile()
	region = ContentDB.get_item(&"regions", &"mossy_hollow") as RegionData


func after_each() -> void:
	GameState.profile = _original_profile
	GameState.run = null
	Hero.god_mode = false


func test_boss_run_starts_at_mother_toad_or_the_warden() -> void:
	var toad: RunState = TestShortcuts.boss_run(region, 0, 7)
	assert_eq(toad.floor_index, 0)
	assert_eq(toad.current_room().type, MapRoom.MINI_BOSS)
	assert_false(toad.room_cleared, "the fight is ahead")
	var warden: RunState = TestShortcuts.boss_run(region, region.floor_count - 1, 7)
	assert_eq(warden.floor_index, region.floor_count - 1)
	assert_eq(warden.current_room().type, MapRoom.BOSS)
	assert_true(warden.is_last_floor())
	warden.mark_cleared()
	assert_true(warden.is_run_won(), "beating the Warden wins the run, so the orbs drop")


func test_training_runs_wait_for_the_village() -> void:
	var text: String = TestShortcuts.add_training_runs(GameState.profile, 3)
	assert_eq(GameState.profile.training_due, 3)
	assert_eq(GameState.profile.run_count, 3)
	assert_true(text.begins_with("+3 runs"), text)


func test_keep_powers_fills_the_slots_only() -> void:
	var hero: HeroState = GameState.hero_state(0)
	TestShortcuts.keep_powers(hero, [&"fire", &"frost", &"stone", &"growth"] as Array[StringName], 5, 3)
	assert_eq(hero.kept_powers.size(), 3)
	assert_eq(hero.kept_powers[0].power_id, &"fire")
	assert_eq(hero.kept_powers[2].level, 5)


func test_menu_buttons_change_the_profile() -> void:
	var menu: TestMenu = load("res://scenes/ui/test_menu.tscn").instantiate()
	menu.save_changes = false
	add_child_autofree(menu)
	await wait_process_frames(1)
	(menu.find_child("OfferFrostButton", true, false) as Button).pressed.emit()
	assert_eq(GameState.hero_state(0).power_offer, [&"frost"] as Array[StringName])
	(menu.find_child("KeepLevel5Button", true, false) as Button).pressed.emit()
	assert_eq(GameState.hero_state(0).kept_powers.size(), 3)
	(menu.find_child("Train3Button", true, false) as Button).pressed.emit()
	assert_eq(GameState.profile.training_due, 3)
	(menu.find_child("RenownButton", true, false) as Button).pressed.emit()
	assert_eq(GameState.profile.village.bonus_renown, 5)
	var god: Button = menu.find_child("GodButton", true, false) as Button
	god.pressed.emit()
	assert_true(Hero.god_mode)
	assert_eq(god.text, "God mode: on")
	assert_true(menu.status_text().begins_with("God mode on"))
