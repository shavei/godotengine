extends GutTest
## GiftSystem (docs/GDD.md Section 3): keep with a 3 slot cap, merge for +1 level,
## release, and kept powers surviving a save.

var balance: BalanceData
var hero: HeroState


func before_each() -> void:
	balance = BalanceData.new()
	hero = HeroState.new()


func test_keep_fills_slots_in_order_up_to_the_cap() -> void:
	assert_eq(GiftSystem.slot_count(balance), 3)
	for id: StringName in [&"fire", &"frost", &"stone"]:
		assert_true(GiftSystem.can_keep(hero, id, balance))
		var kept: KeptPower = GiftSystem.keep(hero, id, balance, 4)
		assert_not_null(kept)
		assert_eq(kept.level, 1)
		assert_eq(kept.last_leveled_run, 4)
	assert_eq(hero.kept_powers.map(func(k: KeptPower) -> StringName: return k.power_id), [&"fire", &"frost", &"stone"])
	assert_false(GiftSystem.can_keep(hero, &"growth", balance), "the 4th power does not fit")
	assert_null(GiftSystem.keep(hero, &"growth", balance))
	assert_eq(hero.kept_powers.size(), 3)


func test_the_same_power_cannot_take_two_slots() -> void:
	GiftSystem.keep(hero, &"fire", balance)
	assert_false(GiftSystem.can_keep(hero, &"fire", balance), "a second Fire is a merge")
	assert_null(GiftSystem.keep(hero, &"fire", balance))
	assert_false(GiftSystem.can_keep(hero, &"", balance))


func test_merge_raises_the_kept_copy_up_to_the_cap() -> void:
	assert_false(GiftSystem.can_merge(hero, &"fire", balance), "nothing to merge into")
	assert_eq(GiftSystem.merge(hero, &"fire", balance), 0)
	GiftSystem.keep(hero, &"fire", balance, 1)
	for expected: int in [2, 3, 4, 5]:
		assert_eq(GiftSystem.merge(hero, &"fire", balance, expected + 10), expected)
	assert_eq(GiftSystem.find(hero, &"fire").last_leveled_run, 15)
	assert_false(GiftSystem.can_merge(hero, &"fire", balance), "level 5 is the cap")
	assert_eq(GiftSystem.merge(hero, &"fire", balance), 0)
	assert_eq(GiftSystem.find(hero, &"fire").level, 5)


func test_merge_works_with_full_slots() -> void:
	for id: StringName in [&"fire", &"frost", &"stone"]:
		GiftSystem.keep(hero, id, balance)
	assert_true(GiftSystem.can_merge(hero, &"frost", balance))
	assert_eq(GiftSystem.merge(hero, &"frost", balance), 2)


func test_release_frees_a_slot_and_later_slots_move_up() -> void:
	for id: StringName in [&"fire", &"frost", &"stone"]:
		GiftSystem.keep(hero, id, balance)
	var released: KeptPower = GiftSystem.release(hero, &"fire")
	assert_eq(released.power_id, &"fire")
	assert_eq(hero.kept_powers[0].power_id, &"frost")
	assert_true(GiftSystem.can_keep(hero, &"growth", balance))
	assert_null(GiftSystem.release(hero, &"fire"))


func test_slot_count_follows_balance() -> void:
	balance.kept_power_slots = 2
	GiftSystem.keep(hero, &"fire", balance)
	GiftSystem.keep(hero, &"frost", balance)
	assert_false(GiftSystem.has_free_slot(hero, balance))


func test_kept_powers_survive_a_save_round_trip() -> void:
	GiftSystem.keep(hero, &"stone", balance, 2)
	GiftSystem.keep(hero, &"growth", balance, 3)
	GiftSystem.merge(hero, &"growth", balance, 7)
	var loaded: HeroState = HeroState.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_eq(loaded.kept_powers.size(), 2)
	assert_eq(loaded.kept_powers[1].power_id, &"growth")
	assert_eq(loaded.kept_powers[1].level, 2)
	assert_eq(loaded.kept_powers[1].last_leveled_run, 7)


func test_old_saves_without_kept_powers_load_empty() -> void:
	var loaded: HeroState = HeroState.from_dict({"level": 3})
	assert_eq(loaded.kept_powers.size(), 0)


# --- Leveling with Power Shards (docs/GDD.md Section 4.3) ---------------------

func test_shard_costs_match_the_gdd() -> void:
	assert_eq(PowerRules.level_up_cost(1, balance), 3, "level 2")
	assert_eq(PowerRules.level_up_cost(2, balance), 5, "level 3")
	assert_eq(PowerRules.level_up_cost(3, balance), 8, "level 4")
	assert_eq(PowerRules.level_up_cost(4, balance), 12, "level 5")
	assert_eq(PowerRules.level_up_cost(5, balance), 0, "no level past the cap")
	assert_eq(PowerRules.total_cost(5, balance), 28, "28 in total")
	assert_eq(PowerRules.total_cost(3, balance), 8)


func test_level_up_spends_banked_shards() -> void:
	GiftSystem.keep(hero, &"fire", balance)
	hero.bank.add(Wallet.SHARDS, 10)
	assert_eq(GiftSystem.level_up_cost(hero, &"fire", balance), 3)
	assert_eq(GiftSystem.level_up(hero, &"fire", balance, 4), 2)
	assert_eq(hero.bank.amount(Wallet.SHARDS), 7)
	assert_eq(GiftSystem.find(hero, &"fire").last_leveled_run, 4, "Fusion tie-break is kept up to date")
	assert_eq(GiftSystem.level_up(hero, &"fire", balance), 3)
	assert_eq(hero.bank.amount(Wallet.SHARDS), 2)
	assert_false(GiftSystem.can_level_up(hero, &"fire", balance), "level 4 costs 8")
	assert_eq(GiftSystem.level_up(hero, &"fire", balance), 0)
	assert_eq(hero.bank.amount(Wallet.SHARDS), 2, "nothing spent on a refused level")


func test_level_up_needs_a_kept_power_below_the_cap() -> void:
	hero.bank.add(Wallet.SHARDS, 100)
	assert_false(GiftSystem.can_level_up(hero, &"frost", balance), "not kept")
	assert_eq(GiftSystem.level_up_cost(hero, &"frost", balance), 0)
	GiftSystem.keep(hero, &"frost", balance)
	for i: int in 4:
		GiftSystem.level_up(hero, &"frost", balance)
	assert_eq(GiftSystem.find(hero, &"frost").level, 5)
	assert_eq(hero.bank.amount(Wallet.SHARDS), 100 - 28)
	assert_false(GiftSystem.can_level_up(hero, &"frost", balance), "capped at 5")


func test_replace_puts_the_new_power_in_the_old_slot() -> void:
	for id: StringName in [&"fire", &"frost", &"stone"]:
		GiftSystem.keep(hero, id, balance)
	hero.kept_powers[1].level = 3
	var gone: KeptPower = GiftSystem.replace(hero, &"frost", &"growth", 6)
	assert_eq(gone.power_id, &"frost")
	assert_eq(gone.level, 3)
	assert_eq(hero.kept_powers.map(func(k: KeptPower) -> StringName: return k.power_id), [&"fire", &"growth", &"stone"])
	assert_eq(hero.kept_powers[1].level, 1, "the new power starts at level 1")
	assert_eq(hero.kept_powers[1].last_leveled_run, 6)
	assert_null(GiftSystem.replace(hero, &"wind", &"frost"), "only a kept power can go")
	assert_null(GiftSystem.replace(hero, &"fire", &"stone"), "the new power is not kept yet")
