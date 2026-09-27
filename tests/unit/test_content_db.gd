extends GutTest
## ContentDB loads data folders without errors. Content arrives in M3+,
## at which point the content integrity checks (docs/ARCHITECTURE.md Section 11) go here.


func test_loads_data_root_without_crashing() -> void:
	var loaded: int = ContentDB.load_all(ContentDB.DATA_ROOT)
	assert_true(loaded >= 0)


func test_unknown_items_return_null_and_empty() -> void:
	assert_null(ContentDB.get_item(&"powers", &"does_not_exist"))
	assert_eq(ContentDB.get_all(&"no_such_category").size(), 0)
	assert_eq(ContentDB.count(&"no_such_category"), 0)


func test_missing_root_loads_nothing() -> void:
	assert_eq(ContentDB.load_all("res://no_such_folder"), 0)
	ContentDB.load_all(ContentDB.DATA_ROOT)


func test_default_balance_matches_gdd_core_numbers() -> void:
	var balance: BalanceData = ContentDB.get_item(&"balance", &"default") as BalanceData
	assert_not_null(balance)
	assert_eq(balance.hero_max_hp, 100)
	assert_eq(balance.hero_max_stamina, 100.0)
	assert_eq(balance.hero_move_speed, 110.0)
	assert_eq(balance.dodge_duration, 0.3)
	assert_eq(balance.dodge_iframes, 0.22)
	assert_eq(balance.dodge_stamina_cost, 25.0)
	assert_eq(balance.stamina_regen, 40.0)
	assert_eq(balance.stamina_regen_delay, 0.5)
	assert_eq(balance.hero_crit_chance, 0.05)
	assert_eq(balance.hero_crit_multiplier, 1.5)
	assert_eq(balance.flask_charges, 3)
	assert_eq(balance.flask_heal_fraction, 0.35)


func test_sword_combo_matches_content_table() -> void:
	var sword: WeaponData = ContentDB.get_item(&"weapons", &"sword") as WeaponData
	assert_not_null(sword)
	var damages: Array[float] = []
	for attack: AttackData in sword.combo:
		damages.append(attack.damage)
	assert_eq(damages, [12.0, 12.0, 20.0] as Array[float])
