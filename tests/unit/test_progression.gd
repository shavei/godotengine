extends GutTest
## XP curve, level-ups, attribute points and weapon mastery (ProgressionSystem, GDD 4.1 and 4.2).

var balance: BalanceData


func before_each() -> void:
	balance = BalanceData.new()


func test_xp_curve_matches_gdd() -> void:
	assert_eq(ProgressionSystem.xp_for_level(2, balance), 141)
	assert_eq(ProgressionSystem.xp_for_level(10, balance), 1581)
	assert_eq(ProgressionSystem.xp_for_level(30, balance), 8216)


func test_add_xp_levels_up_and_carries_the_rest() -> void:
	var hero: HeroState = HeroState.new()
	assert_eq(ProgressionSystem.add_xp(hero, 100, balance), 0)
	assert_eq(hero.level, 1)
	assert_eq(hero.xp, 100)
	assert_eq(ProgressionSystem.add_xp(hero, 50, balance), 1, "141 reaches level 2")
	assert_eq(hero.level, 2)
	assert_eq(hero.xp, 9)
	assert_eq(hero.attribute_points, 1)


func test_one_big_run_can_give_several_levels() -> void:
	var hero: HeroState = HeroState.new()
	# Level 2 needs 141, level 3 needs 260: 401 in all.
	assert_eq(ProgressionSystem.add_xp(hero, 401, balance), 2)
	assert_eq(hero.level, 3)
	assert_eq(hero.xp, 0)
	assert_eq(hero.attribute_points, 2)


func test_level_cap_stops_xp() -> void:
	var hero: HeroState = HeroState.new()
	hero.level = balance.level_cap - 1
	ProgressionSystem.add_xp(hero, 999999, balance)
	assert_eq(hero.level, balance.level_cap)
	assert_eq(hero.xp, 0)
	assert_eq(ProgressionSystem.xp_to_next(hero, balance), 0)
	assert_eq(ProgressionSystem.add_xp(hero, 100, balance), 0)


func test_room_xp_by_type() -> void:
	assert_eq(ProgressionSystem.room_xp(MapRoom.COMBAT, balance), 15)
	assert_eq(ProgressionSystem.room_xp(MapRoom.ELITE, balance), 60)
	assert_eq(ProgressionSystem.room_xp(MapRoom.MINI_BOSS, balance), 100)
	assert_eq(ProgressionSystem.room_xp(MapRoom.BOSS, balance), 200)
	assert_eq(ProgressionSystem.room_xp(MapRoom.REST, balance), 0)


func test_spending_points_needs_points_and_respects_the_cap() -> void:
	var hero: HeroState = HeroState.new()
	assert_false(ProgressionSystem.spend_point(hero, HeroState.MIGHT, balance), "no points yet")
	hero.attribute_points = 2
	assert_true(ProgressionSystem.spend_point(hero, HeroState.MIGHT, balance))
	assert_eq(hero.attribute(HeroState.MIGHT), 1)
	assert_eq(hero.attribute_points, 1)
	assert_false(ProgressionSystem.spend_point(hero, &"luck", balance), "unknown attribute")
	hero.attributes[HeroState.VIGOR] = balance.attribute_cap
	assert_false(ProgressionSystem.spend_point(hero, HeroState.VIGOR, balance), "capped")
	assert_eq(hero.attribute_points, 1)


func test_level_and_attributes_change_hero_stats() -> void:
	var hero: HeroState = HeroState.new()
	assert_eq(ProgressionSystem.max_hp(hero, balance), 100)
	hero.level = 3
	hero.attributes[HeroState.VIGOR] = 2
	hero.attributes[HeroState.MIGHT] = 3
	assert_eq(ProgressionSystem.max_hp(hero, balance), 100 + 8 + 20)
	assert_almost_eq(ProgressionSystem.max_stamina(hero, balance), 110.0, 0.001)
	assert_almost_eq(ProgressionSystem.weapon_damage_bonus(hero, balance), 0.09, 0.0001)


func test_mastery_curve() -> void:
	assert_eq(ProgressionSystem.mastery_xp_for_damage(129, balance), 12, "1 per 10 damage")
	assert_eq(ProgressionSystem.mastery_level(0, balance), 1)
	var level_2: int = ProgressionSystem.mastery_xp_for_level(2, balance)
	assert_eq(level_2, roundi(150.0 * pow(2.0, 1.4)))
	assert_eq(ProgressionSystem.mastery_level(level_2 - 1, balance), 1)
	assert_eq(ProgressionSystem.mastery_level(level_2, balance), 2)
	assert_eq(ProgressionSystem.mastery_level(99999999, balance), balance.mastery_cap)


func test_hero_state_round_trips_through_json() -> void:
	var hero: HeroState = HeroState.new()
	hero.level = 4
	hero.xp = 77
	hero.attribute_points = 1
	hero.attributes[HeroState.MIGHT] = 2
	hero.weapon_mastery[&"sword"] = 321
	hero.bank.add(Wallet.COINS, 140)
	var profile: ProfileState = ProfileState.new()
	profile.heroes[0] = hero
	profile.run_count = 5
	profile.runs_won = 2
	var parsed: Variant = JSON.parse_string(JSON.stringify(profile.to_dict()))
	var loaded: ProfileState = ProfileState.from_dict(parsed)
	assert_eq(loaded.run_count, 5)
	assert_eq(loaded.runs_won, 2)
	var back: HeroState = loaded.hero(0)
	assert_eq(back.level, 4)
	assert_eq(back.xp, 77)
	assert_eq(back.attribute_points, 1)
	assert_eq(back.attribute(HeroState.MIGHT), 2)
	assert_eq(back.mastery_xp(&"sword"), 321)
	assert_eq(back.bank.amount(Wallet.COINS), 140)
	assert_eq(back.to_dict(), hero.to_dict())
