extends GutTest
## Loot rules: Wallet, LootRoller and EventResolver (docs/GDD.md Sections 6.2, 9, 15.3).


func _table(entries: Array[Array]) -> DropTable:
	var table: DropTable = DropTable.new()
	for row: Array in entries:
		var entry: DropEntry = DropEntry.new()
		entry.currency = row[0]
		entry.chance = row[1]
		entry.min_amount = row[2]
		entry.max_amount = row[3]
		table.entries.append(entry)
	return table


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- Wallet -------------------------------------------------------------------

func test_wallet_adds_and_spends() -> void:
	var wallet: Wallet = Wallet.new()
	watch_signals(wallet)
	wallet.add(Wallet.COINS, 30)
	assert_eq(wallet.amount(Wallet.COINS), 30)
	assert_signal_emitted_with_parameters(wallet, "changed", [Wallet.COINS, 30])
	assert_true(wallet.spend(Wallet.COINS, 25))
	assert_eq(wallet.amount(Wallet.COINS), 5)
	assert_false(wallet.spend(Wallet.COINS, 6), "cannot go below zero")
	assert_eq(wallet.amount(Wallet.COINS), 5)
	assert_eq(wallet.amount(Wallet.SHARDS), 0)


func test_wallet_ignores_negative_gains() -> void:
	var wallet: Wallet = Wallet.new()
	wallet.add(Wallet.WOOD, -4)
	assert_eq(wallet.amount(Wallet.WOOD), 0)


func test_spend_all_is_all_or_nothing() -> void:
	var wallet: Wallet = Wallet.new()
	wallet.add(Wallet.COINS, 50)
	wallet.add(Wallet.WOOD, 2)
	assert_false(wallet.spend_all({Wallet.COINS: 20, Wallet.WOOD: 5}))
	assert_eq(wallet.amount(Wallet.COINS), 50, "nothing was taken")
	assert_true(wallet.spend_all({Wallet.COINS: 20, Wallet.WOOD: 2}))
	assert_eq(wallet.amount(Wallet.COINS), 30)
	assert_eq(wallet.amount(Wallet.WOOD), 0)


func test_wallet_round_trips_through_a_dictionary() -> void:
	var wallet: Wallet = Wallet.new()
	wallet.add_all({Wallet.COINS: 12, Wallet.CRYSTAL: 1, Wallet.SHARDS: 3})
	var copy: Wallet = Wallet.from_dict(JSON.parse_string(JSON.stringify(wallet.to_dict())))
	assert_eq(copy.amount(Wallet.COINS), 12)
	assert_eq(copy.amount(Wallet.CRYSTAL), 1)
	assert_eq(copy.amount(Wallet.SHARDS), 3)


func test_run_state_keeps_a_wallet_per_player() -> void:
	var run: RunState = RunState.start(load("res://data/regions/region_mossy_hollow.tres"), 3)
	run.wallet(0).add(Wallet.COINS, 5)
	run.wallet(1).add(Wallet.COINS, 9)
	assert_eq(run.wallet(0).amount(Wallet.COINS), 5)
	assert_eq(run.wallet(1).amount(Wallet.COINS), 9)
	run.enter(run.next_choices()[0])
	assert_eq(run.wallet(0).amount(Wallet.COINS), 5, "loot carries between rooms")


# --- LootRoller ----------------------------------------------------------------

func test_roll_is_seeded() -> void:
	var table: DropTable = _table([[Wallet.COINS, 0.7, 1, 9], [Wallet.WOOD, 0.4, 1, 3]])
	for seed_value: int in [1, 2, 77]:
		assert_eq(LootRoller.roll(table, _rng(seed_value)), LootRoller.roll(table, _rng(seed_value)))


func test_roll_respects_chance_and_range() -> void:
	var table: DropTable = _table([[Wallet.COINS, 1.0, 2, 5], [Wallet.CRYSTAL, 0.0, 1, 1]])
	var rng: RandomNumberGenerator = _rng(5)
	for i: int in 200:
		var gains: Dictionary[StringName, int] = LootRoller.roll(table, rng)
		assert_between(gains.get(Wallet.COINS, 0), 2, 5)
		assert_false(gains.has(Wallet.CRYSTAL), "chance 0 never drops")


func test_roll_of_no_table_is_empty() -> void:
	assert_eq(LootRoller.roll(null, _rng(1)).size(), 0)


func test_split_piles_keeps_the_total() -> void:
	assert_eq(LootRoller.split_piles(7, 3, 6), [3, 2, 2] as Array[int])
	assert_eq(LootRoller.split_piles(40, 3, 6).size(), 6, "capped at 6 piles")
	var total: int = 0
	for pile: int in LootRoller.split_piles(40, 3, 6):
		total += pile
	assert_eq(total, 40)
	assert_eq(LootRoller.split_piles(0, 3, 6).size(), 0)
	assert_eq(LootRoller.split_piles(1, 1, 6), [1] as Array[int])


func test_every_enemy_drops_something_and_elites_drop_shards_and_crystal() -> void:
	for res: Resource in ContentDB.get_all(&"enemies"):
		var data: EnemyData = res as EnemyData
		assert_not_null(data.drops, "%s has drops" % data.id)
		if data.is_elite and data.drops != null:
			# docs/GDD.md Section 6.2: elites give 1 to 2 Power Shards and Crystal.
			var gains: Dictionary[StringName, int] = LootRoller.roll(data.drops, _rng(9))
			assert_between(gains.get(Wallet.SHARDS, 0), 1, 2, "%s shards" % data.id)
			assert_gt(gains.get(Wallet.CRYSTAL, 0), 0, "%s crystal" % data.id)


# --- EventResolver -----------------------------------------------------------

func _choice(cost: Dictionary, hp_cost: float, chance: float, reward: DropTable) -> EventChoiceData:
	var choice: EventChoiceData = EventChoiceData.new()
	choice.cost.assign(cost)
	choice.hp_cost_fraction = hp_cost
	choice.success_chance = chance
	choice.reward = reward
	choice.success_text = "yes"
	choice.fail_text = "no"
	return choice


func test_event_choice_needs_the_cost() -> void:
	var wallet: Wallet = Wallet.new()
	wallet.add(Wallet.COINS, 10)
	var choice: EventChoiceData = _choice({Wallet.COINS: 25}, 0.0, 1.0, null)
	assert_false(EventResolver.can_choose(choice, wallet))
	var outcome: EventOutcome = EventResolver.resolve(choice, wallet, 50, 100, _rng(1))
	assert_false(outcome.paid)
	assert_eq(outcome.hp, 50)
	assert_eq(wallet.amount(Wallet.COINS), 10)


func test_event_success_pays_and_rewards() -> void:
	var wallet: Wallet = Wallet.new()
	wallet.add(Wallet.COINS, 30)
	var choice: EventChoiceData = _choice({Wallet.COINS: 25}, 0.0, 1.0, _table([[Wallet.CRYSTAL, 1.0, 1, 1]]))
	var outcome: EventOutcome = EventResolver.resolve(choice, wallet, 50, 100, _rng(1))
	assert_true(outcome.paid)
	assert_true(outcome.success)
	assert_eq(outcome.gains, {Wallet.CRYSTAL: 1} as Dictionary[StringName, int])
	assert_eq(outcome.text, "yes")
	assert_eq(wallet.amount(Wallet.COINS), 5, "the cost is paid")
	assert_eq(wallet.amount(Wallet.CRYSTAL), 0, "rewards drop as pickups, not straight in")


func test_event_failure_keeps_the_cost() -> void:
	var wallet: Wallet = Wallet.new()
	wallet.add(Wallet.COINS, 30)
	var choice: EventChoiceData = _choice({Wallet.COINS: 25}, 0.0, 0.0, _table([[Wallet.CRYSTAL, 1.0, 1, 1]]))
	var outcome: EventOutcome = EventResolver.resolve(choice, wallet, 50, 100, _rng(1))
	assert_true(outcome.paid)
	assert_false(outcome.success)
	assert_eq(outcome.gains.size(), 0)
	assert_eq(outcome.text, "no")
	assert_eq(wallet.amount(Wallet.COINS), 5)


func test_event_hp_cost_never_kills() -> void:
	var choice: EventChoiceData = _choice({}, 0.2, 1.0, null)
	assert_eq(EventResolver.resolve(choice, Wallet.new(), 100, 100, _rng(1)).hp, 80)
	assert_eq(EventResolver.resolve(choice, Wallet.new(), 5, 100, _rng(1)).hp, 1)
	assert_eq(EventResolver.resolve(choice, Wallet.new(), 1, 100, _rng(1)).hp, 1)


func test_event_heal_is_capped() -> void:
	var choice: EventChoiceData = _choice({}, 0.0, 1.0, null)
	choice.heal_fraction = 0.5
	assert_eq(EventResolver.resolve(choice, Wallet.new(), 80, 100, _rng(1)).hp, 100)


func test_event_caption_shows_the_cost() -> void:
	assert_eq(EventResolver.caption(_choice({Wallet.COINS: 25}, 0.0, 1.0, null)), "\n(25 coins)")
	var blood: EventChoiceData = _choice({}, 0.2, 1.0, null)
	blood.label = "Offer blood"
	assert_eq(EventResolver.caption(blood), "Offer blood\n(20% HP)")


func test_sample_events_are_complete() -> void:
	var events: Array[Resource] = ContentDB.get_all(&"events")
	assert_gte(events.size(), 2, "2 sample events (docs/ROADMAP.md M2)")
	for res: Resource in events:
		var data: EventData = res as EventData
		assert_false(data.title.is_empty(), "%s title" % data.id)
		assert_between(data.choices.size(), 2, 3, "%s choices" % data.id)
		var way_out: EventChoiceData = data.choices.back()
		assert_true(way_out.cost.is_empty() and way_out.hp_cost_fraction == 0.0, "%s last choice is free" % data.id)
		for choice: EventChoiceData in data.choices:
			assert_false(choice.success_text.is_empty(), "%s: %s has a result line" % [data.id, choice.label])
			if choice.success_chance < 1.0:
				assert_false(choice.fail_text.is_empty(), "%s: %s has a fail line" % [data.id, choice.label])
