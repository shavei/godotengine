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


# --- Giving (M4) ------------------------------------------------------------------

func _village(ids: Array[StringName]) -> VillageState:
	var village: VillageState = VillageState.new()
	for i: int in ids.size():
		village.villagers.append(VillagerState.create(ids[i], i))
	return village


func test_give_hands_a_new_power_to_a_villager_for_good() -> void:
	var village: VillageState = _village([&"smith", &"farmer"])
	assert_true(GiftSystem.can_give(village, 1))
	var farmer: VillagerState = GiftSystem.give(village, 1, &"growth")
	assert_eq(farmer, village.villagers[1])
	assert_eq(farmer.power_id, &"growth")
	assert_eq(farmer.training_points, 0, "a level 1 gift starts at 0 TP")
	assert_eq(TrainingSystem.rank(farmer, balance), TrainingSystem.NOVICE)
	assert_false(GiftSystem.can_give(village, 1), "one power per villager")
	assert_null(GiftSystem.give(village, 1, &"fire"), "a gift can never be swapped")
	assert_eq(farmer.power_id, &"growth")
	assert_eq(GiftSystem.open_villagers(village), [0] as Array[int])


func test_give_refuses_a_missing_villager_or_power() -> void:
	var village: VillageState = _village([&"smith"])
	assert_null(GiftSystem.give(village, 3, &"fire"))
	assert_null(GiftSystem.give(village, -1, &"fire"))
	assert_null(GiftSystem.give(village, 0, &""))
	assert_false(village.villagers[0].has_power())


func test_level_carries_over_as_training_points() -> void:
	assert_eq(GiftSystem.starting_tp(1), 0)
	assert_eq(GiftSystem.starting_tp(3), 2)
	assert_eq(GiftSystem.starting_tp(5), 4, "a level 5 gift starts at 4 TP (GDD 3.2)")
	var village: VillageState = _village([&"smith", &"farmer"])
	hero.kept_powers.append(KeptPower.create(&"fire", 4))
	hero.kept_powers.append(KeptPower.create(&"stone", 2))
	var smith: VillagerState = GiftSystem.give_kept(village, hero, &"fire", 0)
	assert_eq(smith.power_id, &"fire")
	assert_eq(smith.training_points, 3)
	assert_eq(TrainingSystem.rank(smith, balance), TrainingSystem.ADEPT, "3 TP is Adept already")
	assert_eq(hero.kept_powers.size(), 1, "the kept power leaves its slot")
	assert_eq(hero.kept_powers[0].power_id, &"stone")


func test_give_kept_needs_the_power_kept_and_a_free_villager() -> void:
	var village: VillageState = _village([&"smith"])
	hero.kept_powers.append(KeptPower.create(&"fire", 2))
	assert_null(GiftSystem.give_kept(village, hero, &"frost", 0), "Frost is not kept")
	GiftSystem.give(village, 0, &"stone")
	assert_null(GiftSystem.give_kept(village, hero, &"fire", 0), "the Smith holds a power")
	assert_eq(hero.kept_powers.size(), 1, "nothing leaves a slot on a refused gift")


func test_giving_a_kept_power_makes_room_for_the_new_one() -> void:
	var village: VillageState = _village([&"smith", &"guard"])
	for id: StringName in [&"fire", &"frost", &"stone"]:
		hero.kept_powers.append(KeptPower.create(id, 3))
	var guard: VillagerState = GiftSystem.give_kept_to_make_room(village, hero, &"frost", &"growth", 1, 7)
	assert_eq(guard.power_id, &"frost")
	assert_eq(guard.training_points, 2)
	assert_eq(hero.kept_powers.map(func(k: KeptPower) -> StringName: return k.power_id), [&"fire", &"growth", &"stone"],
			"Growth takes Frost's slot")
	assert_eq(hero.kept_powers[1].level, 1)
	GiftSystem.give(village, 0, &"fire")
	assert_null(GiftSystem.give_kept_to_make_room(village, hero, &"fire", &"frost", 0, 7), "no free villager, no swap")
	assert_eq(hero.kept_powers[0].power_id, &"fire", "the refused swap keeps the slots as they were")


func test_ranks_follow_training_points() -> void:
	var villager: VillagerState = VillagerState.create(&"smith", 0)
	assert_eq(TrainingSystem.rank(villager, balance), TrainingSystem.NONE, "no power, no rank")
	villager.power_id = &"fire"
	for pair: Array in [[0, TrainingSystem.NOVICE], [2, TrainingSystem.NOVICE], [3, TrainingSystem.ADEPT],
			[6, TrainingSystem.ADEPT], [7, TrainingSystem.MASTER], [12, TrainingSystem.MASTER]]:
		villager.training_points = pair[0]
		assert_eq(TrainingSystem.rank(villager, balance), pair[1], "%d TP" % pair[0])
	assert_eq(TrainingSystem.rank_name(TrainingSystem.ADEPT), "Adept")
