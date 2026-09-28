extends GutTest
## Closing a run (RunEnd, EconomySystem): XP and mastery are kept, loot is banked in full
## on a clear and by half on a fall (GDD 6.4).

var region: RegionData
var balance: BalanceData


func before_all() -> void:
	region = load("res://data/regions/region_mossy_hollow.tres")


func before_each() -> void:
	balance = BalanceData.new()


func _run_with_loot() -> RunState:
	var run: RunState = RunState.start(region, 9)
	run.wallet(0).add_all({Wallet.COINS: 41, Wallet.WOOD: 7, Wallet.SHARDS: 3})
	run.add_xp(0, 150)
	run.add_weapon_damage(0, &"sword", 1234)
	run.rooms_cleared = 4
	run.elapsed = 125.0
	return run


func test_kept_amount_rounds_down() -> void:
	assert_eq(EconomySystem.kept_amount(41, 0.5), 20)
	assert_eq(EconomySystem.kept_amount(1, 0.5), 0)
	assert_eq(EconomySystem.kept_amount(10, 1.0), 10)
	assert_eq(EconomySystem.kept_amount(10, 2.0), 10, "never more than found")


func test_a_clear_banks_everything() -> void:
	var profile: ProfileState = ProfileState.new()
	var summary: RunSummary = RunEnd.finish(_run_with_loot(), profile, true, balance)[0]
	var hero: HeroState = profile.hero(0)
	assert_eq(hero.bank.amount(Wallet.COINS), 41)
	assert_eq(hero.bank.amount(Wallet.WOOD), 7)
	assert_eq(hero.bank.amount(Wallet.SHARDS), 3)
	assert_eq(summary.kept, summary.found)
	assert_true(summary.success)
	assert_eq(profile.run_count, 1)
	assert_eq(profile.runs_won, 1)


func test_a_fall_keeps_half_the_loot_but_all_xp() -> void:
	var profile: ProfileState = ProfileState.new()
	var summary: RunSummary = RunEnd.finish(_run_with_loot(), profile, false, balance)[0]
	var hero: HeroState = profile.hero(0)
	assert_eq(hero.bank.amount(Wallet.COINS), 20)
	assert_eq(hero.bank.amount(Wallet.WOOD), 3)
	assert_eq(hero.bank.amount(Wallet.SHARDS), 1)
	assert_eq(summary.found[Wallet.COINS], 41)
	assert_eq(summary.kept[Wallet.COINS], 20)
	assert_almost_eq(summary.keep_fraction, 0.5, 0.001)
	assert_eq(summary.xp_gained, 150)
	assert_eq(hero.level, 2, "150 XP passes level 2 (141)")
	assert_eq(summary.level_before, 1)
	assert_eq(summary.level_after, 2)
	assert_eq(summary.xp_into_level, 9)
	assert_eq(summary.xp_for_next, 260)
	assert_eq(hero.mastery_xp(&"sword"), 123, "mastery kept in full")
	assert_eq(summary.weapon_id, &"sword")
	assert_eq(summary.mastery_xp_gained, 123)
	assert_eq(profile.run_count, 1)
	assert_eq(profile.runs_won, 0)


func test_banking_adds_to_what_the_hero_had() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.hero(0).bank.add(Wallet.COINS, 100)
	RunEnd.finish(_run_with_loot(), profile, true, balance)
	assert_eq(profile.hero(0).bank.amount(Wallet.COINS), 141)


func test_summary_reports_where_and_how_long() -> void:
	var run: RunState = _run_with_loot()
	var summary: RunSummary = RunEnd.finish(run, ProfileState.new(), false, balance)[0]
	assert_eq(summary.region_name, region.display_name)
	assert_eq(summary.floor_reached, 1)
	assert_eq(summary.floor_count, 3)
	assert_eq(summary.rooms_cleared, 4)
	assert_eq(summary.time_text(), "2:05")


func test_each_hero_banks_their_own_loot() -> void:
	var run: RunState = _run_with_loot()
	run.wallet(1).add(Wallet.COINS, 10)
	run.add_xp(1, 15)
	var profile: ProfileState = ProfileState.new()
	var summaries: Dictionary[int, RunSummary] = RunEnd.finish(run, profile, true, balance)
	assert_eq(summaries.size(), 2)
	assert_eq(profile.hero(1).bank.amount(Wallet.COINS), 10)
	assert_eq(profile.hero(1).xp, 15)
	assert_eq(profile.hero(0).bank.amount(Wallet.COINS), 41)
