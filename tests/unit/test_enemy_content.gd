extends GutTest
## Content integrity for enemies and encounters (docs/ARCHITECTURE.md Section 11).

const M1_ENEMIES: Array[StringName] = [&"sproutling", &"seedling", &"tusk_boar", &"thorn_archer"]


func test_m1_enemies_exist() -> void:
	for id: StringName in M1_ENEMIES:
		assert_not_null(ContentDB.get_item(&"enemies", id), "missing enemy %s" % id)


func test_every_enemy_is_complete() -> void:
	for res: Resource in ContentDB.get_all(&"enemies"):
		var data: EnemyData = res as EnemyData
		assert_not_null(data, "%s is not EnemyData" % res.resource_path)
		if data == null:
			continue
		assert_true(data.max_hp > 0, "%s hp" % data.id)
		assert_not_null(data.attack, "%s has an attack" % data.id)
		assert_not_null(data.ai_script, "%s has an AI script" % data.id)
		if data.ai_script != null:
			assert_true(data.ai_script.new() is EnemyAI, "%s AI extends EnemyAI" % data.id)
		if data.attack != null:
			# docs/GDD.md Section 7.4: every attack telegraphs for 0.4 to 0.8 s.
			assert_between(data.attack.windup, 0.4, 0.8, "%s telegraph length" % data.id)
		assert_eq(data.split_into == null, data.split_count == 0, "%s split fields agree" % data.id)


func test_sproutling_splits_into_two_seedlings() -> void:
	var sproutling: EnemyData = ContentDB.get_item(&"enemies", &"sproutling")
	assert_eq(sproutling.split_into.id, &"seedling")
	assert_eq(sproutling.split_count, 2)


func test_test_encounter_has_four_waves_of_known_enemies() -> void:
	var encounter: EncounterData = ContentDB.get_item(&"encounters", &"mossy_test")
	assert_not_null(encounter)
	assert_eq(encounter.waves.size(), 4)
	for wave: WaveData in encounter.waves:
		assert_gt(wave.enemies.size(), 0)
		for enemy: EnemyData in wave.enemies:
			assert_not_null(ContentDB.get_item(&"enemies", enemy.id), "encounter uses unknown enemy")


func test_mossy_elites_are_one_elite_plus_adds() -> void:
	var region: RegionData = ContentDB.get_item(&"regions", &"mossy_hollow")
	assert_eq(region.elite_encounters.size(), 2, "Elder Boar and Spore Witch (docs/CONTENT.md 6.1)")
	for encounter: EncounterData in region.elite_encounters:
		var elites: int = 0
		var adds: int = 0
		for wave: WaveData in encounter.waves:
			for enemy: EnemyData in wave.enemies:
				if enemy.is_elite:
					elites += 1
				else:
					adds += 1
		assert_eq(elites, 1, "%s has one elite" % encounter.id)
		assert_gt(adds, 0, "%s has adds" % encounter.id)


func test_follow_up_telegraphs_are_long_enough() -> void:
	for res: Resource in ContentDB.get_all(&"enemies"):
		var data: EnemyData = res as EnemyData
		if data.charge_chain > 1:
			assert_between(data.chain_windup, 0.4, 0.8, "%s chain telegraph" % data.id)
		if data.summon != null:
			assert_between(data.summon_windup, 0.4, 0.8, "%s summon telegraph" % data.id)
			assert_gt(data.summon_max_alive, 0)


func test_fight_rooms_have_3_to_4_waves() -> void:
	var region: RegionData = ContentDB.get_item(&"regions", &"mossy_hollow") as RegionData
	for encounter: EncounterData in region.combat_encounters:
		assert_between(encounter.waves.size(), 3, 4, "%s (GDD 6.2, runs of 12 to 15 minutes)" % encounter.id)
