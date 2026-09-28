extends GutTest
## Village services that change runs (M4 PR 2): ModifierStack rules, service content,
## the Smith's shop (ShopSystem), and what services do to the hero in a run.

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero/hero.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/actors/training_dummy/training_dummy.tscn")
## Every target a service may use (plus the income. and raid. families).
const KNOWN_TARGETS: Array[StringName] = [
	ModifierStack.MAX_HP, ModifierStack.MAX_HP_SHARE, ModifierStack.DAMAGE_TAKEN,
	ModifierStack.WEAPON_BURN_CHANCE, ModifierStack.WEAPON_CHILL_CHANCE, ModifierStack.WEAPON_STAGGER,
	ModifierStack.MENDING_STEP, ModifierStack.MENDING_CAP, ModifierStack.HEAL_PER_ROOM,
	ModifierStack.FLASK_HEAL, ModifierStack.FLASK_REGEN, ModifierStack.REVIVE_HP, ModifierStack.REVIVE_BLAST,
	ModifierStack.FLASK_CHARGES, ModifierStack.REVIVES, ModifierStack.FORGE_BONUS,
]

var _original_profile: ProfileState
var _balance: BalanceData


func before_each() -> void:
	HitStop.enabled = false
	_original_profile = GameState.profile
	GameState.new_profile()
	# The Healer moves in at Renown 2.
	GameState.admit_villagers(2)
	_balance = ContentDB.get_item(&"balance", &"default") as BalanceData


func after_each() -> void:
	HitStop.enabled = true
	GameState.profile = _original_profile


func _village() -> VillageState:
	return GameState.profile.village


func _hero_state() -> HeroState:
	return GameState.hero_state(0)


func _combo(villager_id: StringName, power_id: StringName) -> ComboData:
	return ContentDB.get_item(&"combos", ComboData.id_for(villager_id, power_id)) as ComboData


func _give(villager_id: StringName, power_id: StringName, level: int = 1) -> void:
	GiftSystem.give(_village(), _village().index_of(villager_id), power_id, level)


func _spawn_hero() -> Hero:
	var world: Node2D = Node2D.new()
	add_child_autofree(world)
	var hero: Hero = HERO_SCENE.instantiate()
	var input: InputSource = InputSource.new()
	input.name = "ScriptedInput"
	hero.add_child(input)
	hero.position = Vector2(100, 100)
	world.add_child(hero)
	hero.stats.crit_chance = 0.0
	return hero


# --- ModifierStack ----------------------------------------------------------------

func test_total_adds_then_multiplies_and_checks_conditions() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ModifierData.create(&"x", 2.0))
	stack.add(ModifierData.create(&"x", 3.0))
	stack.add(ModifierData.create(&"x", 2.0, ModifierData.MUL))
	stack.add(ModifierData.create(&"x", 10.0, ModifierData.ADD, &"boss_room"))
	stack.add(ModifierData.create(&"y", 7.0))
	assert_eq(stack.total(&"x", 1.0), 12.0, "(1 + 2 + 3) * 2")
	assert_eq(stack.total(&"x", 1.0, [&"boss_room"] as Array[StringName]), 32.0, "the boss-only one joins")
	assert_eq(stack.total(&"missing", 4.0), 4.0)
	assert_eq(stack.count(&"y", 1), 8)
	assert_true(stack.has(&"y"))
	assert_false(stack.has(&"z"))


func test_income_collects_every_currency() -> void:
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ModifierData.create(&"income.coins", 40.0))
	stack.add(ModifierData.create(&"income.coins", 40.0))
	stack.add(ModifierData.create(&"income.wood", 10.0))
	stack.add(ModifierData.create(ModifierStack.FLASK_CHARGES, 1.0))
	assert_eq(stack.income(), {Wallet.COINS: 80, Wallet.WOOD: 10} as Dictionary[StringName, int])


func test_base_services_always_count() -> void:
	var stack: ModifierStack = GameState.services(0)
	assert_eq(stack.count(ModifierStack.FLASK_CHARGES), 1, "the Farmer's extra flask")
	assert_eq(stack.count(ModifierStack.REVIVES), 1, "the Healer's revive token")
	assert_eq(stack.count(&"raid.towers"), 1, "the Guard's tower waits for raids")
	var empty: ModifierStack = ModifierStack.collect(_hero_state(), VillageState.new(), _balance, [] as Array[VillagerData], [] as Array[ComboData])
	assert_true(empty.modifiers.is_empty(), "no villagers, no services")


func test_a_gift_adds_its_novice_service_and_adept_adds_on_top() -> void:
	_give(&"farmer", &"frost")
	assert_eq(GameState.services(0).count(ModifierStack.FLASK_CHARGES), 2, "base +1, Novice +1")
	_village().find(&"farmer").training_points = _balance.adept_tp
	assert_eq(GameState.services(0).count(ModifierStack.FLASK_CHARGES), 3, "Adept +1 more (+2 in all)")


func test_a_priced_service_counts_only_once_bought() -> void:
	_give(&"smith", &"fire")
	assert_eq(GameState.services(0).total(ModifierStack.WEAPON_BURN_CHANCE), 0.0, "not bought yet")
	_hero_state().bought_services.append(&"smith_fire")
	assert_almost_eq(GameState.services(0).total(ModifierStack.WEAPON_BURN_CHANCE), 0.15, 0.001)
	_village().find(&"smith").training_points = _balance.adept_tp
	var stack: ModifierStack = GameState.services(0)
	assert_almost_eq(stack.total(ModifierStack.WEAPON_BURN_CHANCE), 0.3, 0.001)
	assert_eq(stack.count(ModifierStack.FORGE_BONUS), 1, "Runed one Forge level early")


func test_services_are_per_hero() -> void:
	_give(&"smith", &"frost")
	_hero_state().bought_services.append(&"smith_frost")
	GameState.profile.hero(1)
	assert_gt(GameState.services(0).total(ModifierStack.WEAPON_CHILL_CHANCE), 0.0)
	assert_eq(GameState.services(1).total(ModifierStack.WEAPON_CHILL_CHANCE), 0.0, "player 1 did not buy it")


# --- Content --------------------------------------------------------------------

func test_every_service_uses_known_targets() -> void:
	var services: Array[ServiceData] = []
	for item: Resource in ContentDB.get_all(&"villagers"):
		services.append((item as VillagerData).base_service)
	for item: Resource in ContentDB.get_all(&"combos"):
		services.append((item as ComboData).novice)
		services.append((item as ComboData).adept)
	for service: ServiceData in services:
		for modifier: ModifierData in service.modifiers:
			var target: String = String(modifier.target)
			var known: bool = KNOWN_TARGETS.has(modifier.target) or target.begins_with(ModifierStack.INCOME_PREFIX) \
					or target.begins_with(ModifierStack.RAID_PREFIX)
			assert_true(known, "unknown target %s in '%s'" % [target, service.description])
			assert_true(modifier.op == ModifierData.ADD or modifier.op == ModifierData.MUL)


func test_every_prototype_novice_service_does_something() -> void:
	for item: Resource in ContentDB.get_all(&"combos"):
		var combo: ComboData = item as ComboData
		assert_false(combo.novice.modifiers.is_empty(), "%s Novice has modifiers" % combo.id)
		assert_false(combo.adept.modifiers.is_empty(), "%s Adept has modifiers" % combo.id)


func test_smith_services_are_sold_and_others_are_free() -> void:
	for item: Resource in ContentDB.get_all(&"combos"):
		var combo: ComboData = item as ComboData
		if combo.villager_id == &"smith":
			assert_gt(combo.novice.price, 0, "%s is bought at the Forge" % combo.id)
			assert_false(combo.novice.shop_name.is_empty())
		else:
			assert_eq(combo.novice.price, 0, "%s is always on" % combo.id)
		assert_eq(combo.adept.price, 0, "Adept upgrades are never bought again")
	var smith: VillagerData = ContentDB.get_item(&"villagers", &"smith") as VillagerData
	assert_true(smith.base_service.sells_weapon_tiers)


func test_guard_services_wait_for_raids() -> void:
	var guard: VillagerData = ContentDB.get_item(&"villagers", &"guard") as VillagerData
	assert_true(guard.base_service.only_in_raids())
	assert_true(_combo(&"guard", &"stone").novice.only_in_raids())
	assert_false(_combo(&"healer", &"stone").novice.only_in_raids())


# --- ShopSystem ------------------------------------------------------------------

func test_the_smith_sells_steel_at_forge_level_two() -> void:
	var hero: HeroState = _hero_state()
	var smith: VillagerState = _village().find(&"smith")
	var forge: int = ShopSystem.forge_level(_village(), &"smith", GameState.services(0))
	assert_eq(forge, VillageState.WORKPLACE_LEVEL_UNTIL_M6)
	assert_eq(ShopSystem.next_tier(hero, &"sword", _balance), 1)
	assert_eq(ShopSystem.tier_problem(hero, &"sword", smith, forge, _balance), "Not enough coins.")
	hero.bank.add(Wallet.COINS, 350)
	assert_eq(ShopSystem.tier_problem(hero, &"sword", smith, forge, _balance), "")
	assert_eq(ShopSystem.buy_tier(hero, &"sword", smith, forge, _balance), 1)
	assert_eq(hero.weapon_tier(&"sword"), 1)
	assert_eq(hero.bank.amount(Wallet.COINS), 50)
	assert_eq(ShopSystem.tier_multiplier(1, _balance), 1.3)
	hero.bank.add(Wallet.COINS, 2000)
	assert_eq(ShopSystem.tier_problem(hero, &"sword", smith, forge, _balance), "Runed needs Forge level 3.")
	assert_eq(ShopSystem.buy_tier(hero, &"sword", smith, forge, _balance), -1)


func test_a_fire_adept_smith_sells_runed_early_and_mythic_needs_a_master() -> void:
	var hero: HeroState = _hero_state()
	_give(&"smith", &"fire", 4)
	hero.bought_services.append(&"smith_fire")
	var smith: VillagerState = _village().find(&"smith")
	var forge: int = ShopSystem.forge_level(_village(), &"smith", GameState.services(0))
	assert_eq(forge, 3, "one Forge level early")
	hero.bank.add(Wallet.COINS, 5000)
	hero.weapon_tiers[&"sword"] = 1
	assert_eq(ShopSystem.buy_tier(hero, &"sword", smith, forge, _balance), 2)
	assert_eq(ShopSystem.tier_problem(hero, &"sword", smith, forge, _balance), "Mythic needs a Master Smith.")
	smith.training_points = _balance.master_tp
	assert_eq(ShopSystem.tier_problem(hero, &"sword", smith, forge, _balance), "Not enough Crystal.")
	hero.bank.add(Wallet.CRYSTAL, 10)
	assert_eq(ShopSystem.buy_tier(hero, &"sword", smith, forge, _balance), 3)
	assert_eq(ShopSystem.next_tier(hero, &"sword", _balance), -1)
	assert_eq(ShopSystem.tier_problem(hero, &"sword", smith, forge, _balance), "Your weapon is at its best tier.")


func test_a_service_is_bought_once() -> void:
	var hero: HeroState = _hero_state()
	var combo: ComboData = _combo(&"smith", &"stone")
	assert_eq(ShopSystem.service_problem(hero, combo), "Not enough coins.")
	hero.bank.add(Wallet.COINS, combo.novice.price)
	assert_true(ShopSystem.buy_service(hero, combo))
	assert_true(hero.has_bought(combo.id))
	assert_eq(hero.bank.amount(Wallet.COINS), 0)
	hero.bank.add(Wallet.COINS, 500)
	assert_false(ShopSystem.buy_service(hero, combo), "once only")
	assert_eq(ShopSystem.service_problem(_hero_state(), _combo(&"farmer", &"stone")), "Nothing to buy.")


func test_tiers_and_purchases_survive_a_save_round_trip() -> void:
	var hero: HeroState = _hero_state()
	hero.weapon_tiers[&"sword"] = 2
	hero.bought_services.append(&"smith_frost")
	var copy: HeroState = HeroState.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_eq(copy.weapon_tier(&"sword"), 2)
	assert_true(copy.has_bought(&"smith_frost"))
	var old: HeroState = HeroState.from_dict({"level": 2})
	assert_eq(old.weapon_tier(&"sword"), 0, "old saves start at Iron")
	assert_true(old.bought_services.is_empty())


# --- Respec --------------------------------------------------------------------------

func test_respec_refunds_points_for_coins() -> void:
	var hero: HeroState = _hero_state()
	hero.level = 4
	hero.attributes[HeroState.VIGOR] = 3
	assert_eq(ProgressionSystem.respec_cost(hero, _balance), 200)
	assert_false(ProgressionSystem.respec(hero, _balance), "not enough coins")
	hero.bank.add(Wallet.COINS, 250)
	assert_true(ProgressionSystem.respec(hero, _balance))
	assert_eq(hero.attribute(HeroState.VIGOR), 0)
	assert_eq(hero.attribute_points, 3)
	assert_eq(hero.bank.amount(Wallet.COINS), 50)
	assert_false(ProgressionSystem.can_respec(hero, _balance), "nothing spent now")


# --- The hero in a run --------------------------------------------------------------

func test_services_set_flasks_revives_and_max_hp() -> void:
	_give(&"healer", &"stone")
	_give(&"farmer", &"fire")
	var hero: Hero = _spawn_hero()
	hero.apply_progress(_hero_state())
	hero.apply_services(GameState.services(0))
	assert_eq(hero.health.max_hp, 120, "Stone Healer +20")
	assert_eq(hero.health.hp, 120)
	assert_eq(hero.flasks.max_charges, _balance.flask_charges + 1, "the Farmer's base flask")
	assert_eq(hero.flasks.charges, hero.flasks.max_charges)
	assert_almost_eq(hero.flasks.heal_fraction, _balance.flask_heal_fraction * 1.25, 0.001, "Fire Farmer")
	assert_eq(hero.revives, 1)
	hero.apply_services(GameState.services(0))
	assert_eq(hero.health.max_hp, 120, "applying twice does not stack")


func test_a_share_of_max_hp_comes_after_the_flat_bonus() -> void:
	var hero: Hero = _spawn_hero()
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ModifierData.create(ModifierStack.MAX_HP, 20.0))
	stack.add(ModifierData.create(ModifierStack.MAX_HP_SHARE, 0.15))
	hero.apply_services(stack)
	assert_eq(hero.health.max_hp, 138, "(100 + 20) * 1.15")


func test_the_frost_salve_counts_only_in_boss_rooms() -> void:
	_give(&"healer", &"frost")
	var hero: Hero = _spawn_hero()
	hero.apply_services(GameState.services(0))
	assert_eq(hero.stats.damage_taken_multiplier, 1.0)
	hero.apply_services(GameState.services(0), [ModifierStack.BOSS_ROOM] as Array[StringName])
	assert_almost_eq(hero.stats.damage_taken_multiplier, 0.9, 0.001)


func test_a_revive_token_gets_the_hero_back_up_once() -> void:
	var hero: Hero = _spawn_hero()
	hero.apply_services(GameState.services(0))
	watch_signals(EventBus)
	watch_signals(hero)
	hero.health.take_damage(500)
	assert_false(hero.health.is_dead(), "the Healer's token")
	assert_eq(hero.health.hp, 30, "30% of 100")
	assert_eq(hero.revives, 0)
	assert_true(hero.has_iframes())
	assert_signal_emitted(hero, "revived")
	assert_signal_emitted_with_parameters(EventBus, "hero_revived", [0])
	assert_signal_not_emitted(EventBus, "hero_died")
	hero.health.take_damage(500)
	assert_true(hero.health.is_dead(), "no token left")
	assert_signal_emitted(EventBus, "hero_died")


func test_a_fire_healer_revive_bursts_and_an_adept_one_revives_higher() -> void:
	_give(&"healer", &"fire", 4)
	var hero: Hero = _spawn_hero()
	hero.apply_services(GameState.services(0))
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = hero.position + Vector2(20, 0)
	hero.get_parent().add_child(dummy)
	await wait_physics_frames(2)
	var dummy_hp: int = dummy.health.hp
	hero.health.take_damage(500)
	assert_eq(hero.health.hp, 50, "Adept: revive at 50%")
	await wait_physics_frames(4)
	assert_lt(dummy.health.hp, dummy_hp, "the fire burst hits what stands close")


func test_infusions_burn_chill_and_stagger() -> void:
	var hero: Hero = _spawn_hero()
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ModifierData.create(ModifierStack.WEAPON_BURN_CHANCE, 1.0))
	stack.add(ModifierData.create(ModifierStack.WEAPON_CHILL_CHANCE, 1.0))
	stack.add(ModifierData.create(ModifierStack.WEAPON_STAGGER, 0.5))
	hero.apply_services(stack)
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = Vector2(300, 300)
	hero.get_parent().add_child(dummy)
	await wait_physics_frames(1)
	var attack: AttackData = AttackData.new()
	attack.stagger = 20.0
	hero.apply_infusions(dummy.hurtbox, attack)
	assert_true(dummy.status.has(StatusEffects.BURN))
	assert_true(dummy.status.has(StatusEffects.CHILL))
	assert_almost_eq(dummy.status.effects.stagger, 10.0, 0.01, "half the swing's stagger again")


func test_no_infusion_does_nothing() -> void:
	var hero: Hero = _spawn_hero()
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	hero.get_parent().add_child(dummy)
	await wait_physics_frames(1)
	hero.apply_infusions(dummy.hurtbox, AttackData.new())
	assert_false(dummy.status.has(StatusEffects.BURN))
	assert_false(dummy.status.has(StatusEffects.CHILL))


func test_mending_gear_grows_per_clean_room_up_to_its_cap() -> void:
	_give(&"smith", &"growth")
	_hero_state().bought_services.append(&"smith_growth")
	var hero: Hero = _spawn_hero()
	hero.apply_progress(_hero_state())
	hero.apply_services(GameState.services(0))
	assert_eq(hero.stats.damage_bonus, 0.0)
	hero.set_mending(3)
	assert_almost_eq(hero.stats.damage_bonus, 0.15, 0.001)
	hero.set_mending(9)
	assert_almost_eq(hero.stats.damage_bonus, 0.25, 0.001, "Novice cap")
	hero.set_mending(0)
	assert_eq(hero.stats.damage_bonus, 0.0)


func test_a_growth_farmer_flask_keeps_healing() -> void:
	var hero: Hero = _spawn_hero()
	var stack: ModifierStack = ModifierStack.new()
	stack.add(ModifierData.create(ModifierStack.FLASK_REGEN, 0.15))
	hero.apply_services(stack)
	hero.health.take_damage(60)
	hero.start_flask_regen()
	assert_true(hero.is_regenerating())
	await wait_seconds(_balance.flask_regen_time + 0.3)
	assert_false(hero.is_regenerating())
	assert_between(hero.health.hp, 54, 55, "15 HP over 5 s")


func test_the_weapon_tier_raises_weapon_damage() -> void:
	_hero_state().weapon_tiers[&"sword"] = 2
	var hero: Hero = _spawn_hero()
	hero.apply_progress(_hero_state())
	assert_almost_eq(hero.stats.weapon_tier, 1.7, 0.001, "Runed")


# --- Run end ----------------------------------------------------------------------

func test_village_income_is_banked_in_full_even_after_a_fall() -> void:
	_give(&"farmer", &"stone")
	var region: RegionData = ContentDB.get_item(&"regions", &"mossy_hollow") as RegionData
	var run: RunState = RunState.start(region, 3)
	run.wallet(0).add(Wallet.COINS, 20)
	var services: Dictionary[int, ModifierStack] = {0: GameState.services(0)}
	var summaries: Dictionary[int, RunSummary] = RunEnd.finish(run, GameState.profile, false, _balance, services)
	assert_eq(_hero_state().bank.amount(Wallet.COINS), 10 + 40, "half the loot, all the income")
	assert_eq(summaries[0].income, {Wallet.COINS: 40} as Dictionary[StringName, int])
