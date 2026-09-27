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


func test_test_encounter_has_three_waves_of_known_enemies() -> void:
	var encounter: EncounterData = ContentDB.get_item(&"encounters", &"mossy_test")
	assert_not_null(encounter)
	assert_eq(encounter.waves.size(), 3)
	for wave: WaveData in encounter.waves:
		assert_gt(wave.enemies.size(), 0)
		for enemy: EnemyData in wave.enemies:
			assert_not_null(ContentDB.get_item(&"enemies", enemy.id), "encounter uses unknown enemy")
