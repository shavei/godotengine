extends GutTest
## PowerOffer (docs/GDD.md Section 3.1): the region boss offers orbs of different powers
## from the region's pool, the hero takes one, then keeps, merges or leaves it.

var balance: BalanceData
var hero: HeroState
var pool: Array[PowerData] = []


func before_all() -> void:
	var region: RegionData = load("res://data/regions/region_mossy_hollow.tres")
	pool = region.power_pool


func before_each() -> void:
	balance = BalanceData.new()
	hero = HeroState.new()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_mossy_hollow_offers_the_four_prototype_powers() -> void:
	var ids: Array = pool.map(func(power: PowerData) -> String: return String(power.id))
	ids.sort()
	assert_eq(ids, ["fire", "frost", "growth", "stone"])


func test_offer_is_two_different_powers_from_the_pool() -> void:
	for seed_value: int in 40:
		var offer: Array[StringName] = PowerOffer.roll(pool, hero, balance, _rng(seed_value))
		assert_eq(offer.size(), 2)
		assert_ne(offer[0], offer[1])
		for power_id: StringName in offer:
			assert_true(power_id in [&"fire", &"frost", &"growth", &"stone"])


func test_offer_is_seeded() -> void:
	var first: Array[StringName] = PowerOffer.roll(pool, hero, balance, PowerOffer.rng_for(77))
	var second: Array[StringName] = PowerOffer.roll(pool, hero, balance, PowerOffer.rng_for(77))
	assert_eq(first, second, "co-op peers roll the same orbs")


func test_every_power_can_be_offered() -> void:
	var seen: Dictionary = {}
	for seed_value: int in 60:
		for power_id: StringName in PowerOffer.roll(pool, hero, balance, _rng(seed_value)):
			seen[power_id] = true
	assert_eq(seen.size(), 4)


func test_a_kept_power_at_the_cap_is_not_offered_while_others_are_left() -> void:
	hero.kept_powers.append(KeptPower.create(&"fire", 5))
	for seed_value: int in 40:
		assert_false(PowerOffer.roll(pool, hero, balance, _rng(seed_value)).has(&"fire"))


func test_maxed_powers_fill_in_when_the_pool_runs_short() -> void:
	for id: StringName in [&"fire", &"frost", &"stone"]:
		hero.kept_powers.append(KeptPower.create(id, 5))
	var offer: Array[StringName] = PowerOffer.roll(pool, hero, balance, _rng(3))
	assert_eq(offer.size(), 2)
	assert_eq(offer[0], &"growth", "the only fresh power comes first")


func test_small_or_empty_pools() -> void:
	var one: Array[PowerData] = [pool[0], pool[0]]
	assert_eq(PowerOffer.roll(one, hero, balance, _rng(1)), [pool[0].id] as Array[StringName], "no duplicates")
	assert_eq(PowerOffer.roll([] as Array[PowerData], hero, balance, _rng(1)).size(), 0)
	balance.boss_orb_count = 3
	assert_eq(PowerOffer.roll(pool, hero, balance, _rng(1)).size(), 3)


func test_taking_an_orb_leaves_only_that_power() -> void:
	hero.power_offer = [&"fire", &"stone"] as Array[StringName]
	assert_true(PowerOffer.is_picking(hero))
	assert_eq(PowerOffer.waiting_power(hero), &"")
	assert_false(PowerOffer.take(hero, &"frost"), "not offered")
	assert_true(PowerOffer.take(hero, &"stone"))
	assert_false(PowerOffer.is_picking(hero))
	assert_eq(PowerOffer.waiting_power(hero), &"stone")
	PowerOffer.clear(hero)
	assert_eq(PowerOffer.waiting_power(hero), &"")


func test_choice_for_each_situation() -> void:
	assert_eq(PowerOffer.choice_for(hero, &"fire", balance), PowerOffer.KEEP)
	GiftSystem.keep(hero, &"fire", balance)
	assert_eq(PowerOffer.choice_for(hero, &"fire", balance), PowerOffer.MERGE)
	hero.kept_powers[0].level = 5
	assert_eq(PowerOffer.choice_for(hero, &"fire", balance), PowerOffer.MAXED)
	GiftSystem.keep(hero, &"frost", balance)
	GiftSystem.keep(hero, &"stone", balance)
	assert_eq(PowerOffer.choice_for(hero, &"growth", balance), PowerOffer.REPLACE)


func test_offer_survives_a_save_round_trip() -> void:
	hero.power_offer = [&"growth", &"frost"] as Array[StringName]
	var loaded: HeroState = HeroState.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_eq(loaded.power_offer, [&"growth", &"frost"] as Array[StringName])
	assert_eq(HeroState.from_dict({}).power_offer.size(), 0, "old saves have no offer")


func test_a_clear_rolls_the_offer_and_a_fall_does_not() -> void:
	var region: RegionData = load("res://data/regions/region_mossy_hollow.tres")
	var profile: ProfileState = ProfileState.new()
	var won: RunState = RunState.start(region, 12)
	won.add_xp(0, 10)
	var summary: RunSummary = RunEnd.finish(won, profile, true, balance)[0]
	assert_eq(profile.hero(0).power_offer.size(), 2)
	assert_eq(summary.power_offer, profile.hero(0).power_offer)
	assert_eq(profile.hero(0).power_offer, PowerOffer.roll(region.power_pool, HeroState.new(), balance, PowerOffer.rng_for(12)))
	var fell_profile: ProfileState = ProfileState.new()
	var lost: RunState = RunState.start(region, 12)
	lost.add_xp(0, 10)
	summary = RunEnd.finish(lost, fell_profile, false, balance)[0]
	assert_eq(fell_profile.hero(0).power_offer.size(), 0, "a fall gives no power")
	assert_eq(summary.power_offer.size(), 0)
