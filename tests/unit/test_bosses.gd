extends GutTest
## Bosses: the BossPattern rules, boss content, and Mother Toad and the Warden of
## Roots (phase 1) against a scripted hero.

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero/hero.tscn")

var world: Node2D
var hero: Hero


func before_each() -> void:
	HitStop.enabled = false
	world = Node2D.new()
	add_child_autofree(world)
	hero = HERO_SCENE.instantiate()
	var input: InputSource = InputSource.new()
	input.name = "ScriptedInput"
	hero.add_child(input)
	hero.position = Vector2(200, 200)
	world.add_child(hero)
	hero.stats.crit_chance = 0.0


func after_each() -> void:
	HitStop.enabled = true
	Engine.time_scale = 1.0


func _boss(id: StringName, pos: Vector2, moves: Array[StringName] = []) -> Enemy:
	var boss: Enemy = Enemy.create(ContentDB.get_item(&"enemies", id))
	boss.position = pos
	world.add_child(boss)
	if not moves.is_empty():
		(boss.ai as BossAI).pattern = BossPattern.new(moves)
	boss.ai.cooldown = 0.0
	return boss


func _children_of_type(type: Script) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in world.get_children():
		if is_instance_of(child, type) and not child.is_queued_for_deletion():
			found.append(child)
	return found


# --- BossPattern ---------------------------------------------------------------

func test_pattern_repeats_its_moves_in_order() -> void:
	var pattern: BossPattern = BossPattern.new([&"a", &"b", &"c"] as Array[StringName])
	var seen: Array[StringName] = []
	for i: int in 7:
		seen.append(pattern.next(1.0))
	assert_eq(seen, [&"a", &"b", &"c", &"a", &"b", &"c", &"a"] as Array[StringName])


func test_pattern_enrages_once_below_the_line_and_starts_the_new_order() -> void:
	var pattern: BossPattern = BossPattern.new([&"a", &"b"] as Array[StringName], [&"x", &"y"] as Array[StringName], 0.5)
	assert_eq(pattern.next(0.9), &"a")
	assert_false(pattern.check_enrage(0.5), "exactly on the line is not below it")
	assert_true(pattern.check_enrage(0.4))
	assert_false(pattern.check_enrage(0.3), "only once")
	assert_eq(pattern.next(0.4), &"x", "the enraged order starts from its first move")
	assert_eq(pattern.next(0.9), &"y", "healing does not calm a boss down")
	assert_eq(pattern.next(0.9), &"x")


func test_pattern_without_enrage_never_enrages() -> void:
	var no_line: BossPattern = BossPattern.new([&"a"] as Array[StringName], [&"x"] as Array[StringName], 0.0)
	var no_moves: BossPattern = BossPattern.new([&"a"] as Array[StringName], [] as Array[StringName], 0.5)
	assert_eq(no_line.next(0.01), &"a")
	assert_eq(no_moves.next(0.01), &"a")
	assert_false(no_line.enraged or no_moves.enraged)
	assert_eq(BossPattern.new().next(1.0), &"", "no moves at all")


func test_fan_spreads_evenly_around_the_aim() -> void:
	var fan: Array[Vector2] = WardenAI.fan(Vector2.RIGHT * 10.0, 5, 60.0)
	assert_eq(fan.size(), 5)
	assert_almost_eq(fan[2].angle(), 0.0, 0.001, "the middle shot goes straight")
	assert_almost_eq(fan[0].angle(), deg_to_rad(-30.0), 0.001)
	assert_almost_eq(fan[4].angle(), deg_to_rad(30.0), 0.001)
	assert_eq(WardenAI.fan(Vector2.UP, 1, 60.0), [Vector2.UP] as Array[Vector2])


# --- Content -------------------------------------------------------------------

func test_mossy_bosses_are_boss_data_the_region_uses() -> void:
	var region: RegionData = ContentDB.get_item(&"regions", &"mossy_hollow")
	var toad: BossData = region.mini_boss_encounter.waves[0].enemies[0] as BossData
	var warden: BossData = region.boss_encounter.waves[0].enemies[0] as BossData
	assert_not_null(toad)
	assert_not_null(warden)
	assert_eq(toad.id, &"mother_toad")
	assert_eq(warden.id, &"warden_of_roots")
	assert_eq(region.mini_boss_encounter.waves.size(), 1, "the boss fights alone")
	assert_eq(region.boss_encounter.waves.size(), 1)


func test_boss_moves_are_known_and_telegraphed() -> void:
	var known: Dictionary = {
		MotherToadAI: [MotherToadAI.TONGUE, MotherToadAI.FLOP],
		WardenAI: [WardenAI.VOLLEY, WardenAI.ROOTS],
	}
	for res: Resource in ContentDB.get_all(&"enemies"):
		var boss: BossData = res as BossData
		if boss == null:
			continue
		assert_eq(boss.hit_stun, 0.0, "%s shrugs off hits" % boss.id)
		assert_false(boss.pattern.is_empty(), "%s has moves" % boss.id)
		var moves: Array = known.get(boss.ai_script, [])
		for move: StringName in boss.pattern + boss.enraged_pattern:
			assert_true(moves.has(move), "%s knows the move %s" % [boss.id, move])
		# docs/GDD.md Section 7.4: every attack telegraphs for 0.4 to 0.8 s.
		for attack: AttackData in [boss.tongue, boss.root_wall, boss.close_attack]:
			if attack != null:
				assert_between(attack.windup, 0.4, 0.8, "%s telegraph length" % boss.id)
		assert_eq(boss.enrage_below > 0.0, not boss.enraged_pattern.is_empty(), "%s enrage fields agree" % boss.id)


# --- Mother Toad ---------------------------------------------------------------

func test_toad_tongue_hits_and_pulls_the_hero_in() -> void:
	var toad: Enemy = _boss(&"mother_toad", Vector2(320, 200), [MotherToadAI.TONGUE] as Array[StringName])
	watch_signals(toad)
	await wait_seconds(1.1)
	assert_signal_emitted(toad, "telegraph_started")
	assert_lt(hero.health.hp, hero.health.max_hp, "the tongue landed")
	assert_gt(hero.position.x, 250.0, "the hero was pulled toward the toad")



func test_toad_tongue_never_hits_behind_her() -> void:
	var toad: Enemy = _boss(&"mother_toad", Vector2(320, 200), [MotherToadAI.TONGUE] as Array[StringName])
	var ai: MotherToadAI = toad.ai as MotherToadAI
	while ai.phase != MotherToadAI.Phase.TONGUE_WINDUP:
		await wait_physics_frames(1)
	# She aims at the hero (to her left); the hero dodges through her to her back.
	hero.global_position = toad.global_position + Vector2(10, 0)
	await wait_seconds(toad.data.tongue.windup + toad.data.tongue.active + 0.05)
	assert_eq(hero.health.hp, hero.health.max_hp, "the tongue only reaches out in front of her")


func test_toad_flop_leaps_to_the_marked_spot_and_lands_hard() -> void:
	var toad: Enemy = _boss(&"mother_toad", Vector2(320, 200), [MotherToadAI.FLOP] as Array[StringName])
	var boss: BossData = toad.data
	await wait_seconds(boss.attack.windup + boss.leap_time * 0.5)
	assert_true((toad.ai as MotherToadAI).is_airborne())
	assert_true(toad.hurtbox_shape.disabled, "she cannot be hit in the air")
	assert_true(toad.body_shape.disabled)
	await wait_seconds(boss.leap_time * 0.5 + 0.2)
	assert_false((toad.ai as MotherToadAI).is_airborne())
	assert_false(toad.hurtbox_shape.disabled)
	assert_almost_eq(toad.global_position.distance_to(Vector2(200, 200)), 0.0, 30.0, "landed on the spot")
	assert_eq(hero.health.hp, hero.health.max_hp - roundi(boss.attack.damage), "the landing hit")


func test_dodging_the_flop_avoids_it() -> void:
	var toad: Enemy = _boss(&"mother_toad", Vector2(320, 200), [MotherToadAI.FLOP] as Array[StringName])
	for i: int in 90:
		hero.grant_iframes(0.1)
		await wait_physics_frames(1)
	assert_eq(hero.health.hp, hero.health.max_hp)
	assert_false((toad.ai as MotherToadAI).is_airborne())


func test_toad_enrages_below_half_hp() -> void:
	var toad: Enemy = _boss(&"mother_toad", Vector2(320, 200))
	var ai: MotherToadAI = toad.ai
	watch_signals(toad)
	toad.health.take_damage(toad.health.max_hp - roundi(toad.health.max_hp * 0.4))
	await wait_physics_frames(3)
	assert_signal_emitted(toad, "enraged")
	assert_true(ai.pattern.enraged)
	assert_eq(ai.pattern.enraged_moves, (toad.data as BossData).enraged_pattern)


func test_hits_do_not_interrupt_a_boss() -> void:
	var toad: Enemy = _boss(&"mother_toad", Vector2(320, 200), [MotherToadAI.TONGUE] as Array[StringName])
	await wait_seconds(0.3)
	var ai: MotherToadAI = toad.ai
	assert_eq(ai.phase, MotherToadAI.Phase.TONGUE_WINDUP)
	toad.health.take_damage(5)
	hero.hitbox.attack = AttackData.new()
	toad.hurtbox.hurt.emit(DamageResult.new(), hero.hitbox)
	await wait_physics_frames(2)
	assert_eq(ai.phase, MotherToadAI.Phase.TONGUE_WINDUP, "still winding up")


# --- Warden of Roots -------------------------------------------------------------

func test_warden_fires_a_fan_of_seeds() -> void:
	var warden: Enemy = _boss(&"warden_of_roots", Vector2(200, 40), [WardenAI.VOLLEY] as Array[StringName])
	var boss: BossData = warden.data
	# An array, since a lambda cannot change a captured int.
	var seeds: Array[Node] = []
	world.child_entered_tree.connect(func(node: Node) -> void:
		if node is ThornArrow:
			seeds.append(node))
	await wait_seconds(boss.attack.windup + 0.1)
	assert_eq(seeds.size(), boss.volley_count)
	await wait_seconds(1.2)
	assert_lt(hero.health.hp, hero.health.max_hp, "the middle seed hits")
	assert_eq(_children_of_type(ThornPatch).size(), 0, "seeds leave no thorns")


func test_warden_never_walks() -> void:
	var warden: Enemy = _boss(&"warden_of_roots", Vector2(200, 40), [WardenAI.VOLLEY] as Array[StringName])
	await wait_seconds(1.0)
	assert_eq(warden.position, Vector2(200, 40))


func test_root_walls_hem_the_hero_in_then_wither_with_the_warden() -> void:
	var warden: Enemy = _boss(&"warden_of_roots", Vector2(200, 60), [WardenAI.ROOTS] as Array[StringName])
	var boss: BossData = warden.data
	await wait_physics_frames(3)
	var walls: Array[Node] = _children_of_type(RootWall)
	assert_eq(walls.size(), 2)
	for wall: RootWall in walls:
		assert_false(wall.is_solid(), "only an outline while warning")
		assert_almost_eq(absf(wall.global_position.x - 200.0), boss.root_wall_gap, 1.0, "one on each side")
		assert_almost_eq(absf(sin(wall.rotation)), 1.0, 0.01, "running along the line to the Warden")
	await wait_seconds(boss.root_wall.windup + 0.1)
	for wall: RootWall in walls:
		assert_true(wall.is_solid())
	assert_eq(hero.health.hp, hero.health.max_hp, "standing between them is safe")
	warden.health.take_damage(9999)
	await wait_seconds(RootWall.FADE_TIME + 0.2)
	assert_eq(_children_of_type(RootWall).size(), 0, "the walls wither with their maker")


func test_root_wall_bursting_under_the_hero_hurts() -> void:
	var warden: Enemy = _boss(&"warden_of_roots", Vector2(200, 60))
	var boss: BossData = warden.data
	warden.ai.cooldown = 99.0
	warden.raise_root_wall(hero.global_position, Vector2.DOWN)
	await wait_seconds(boss.root_wall.windup + 0.1)
	assert_eq(hero.health.hp, hero.health.max_hp - roundi(boss.root_wall.damage))


func test_root_wall_blocks_seeds() -> void:
	var warden: Enemy = _boss(&"warden_of_roots", Vector2(200, 60))
	var boss: BossData = warden.data
	warden.ai.cooldown = 99.0
	warden.raise_root_wall(Vector2(200, 140), Vector2.RIGHT)
	await wait_seconds(boss.root_wall.windup + 0.1)
	warden.fire_projectile(Vector2.DOWN)
	await wait_seconds(1.2)
	assert_eq(hero.health.hp, hero.health.max_hp, "the wall caught the seed")


func test_warden_slams_a_hero_standing_next_to_it() -> void:
	var warden: Enemy = _boss(&"warden_of_roots", Vector2(200, 160), [WardenAI.VOLLEY] as Array[StringName])
	var boss: BossData = warden.data
	await wait_seconds(boss.close_attack.windup + 0.2)
	assert_eq(hero.health.hp, hero.health.max_hp - roundi(boss.close_attack.damage))
	assert_eq(_children_of_type(ThornArrow).size(), 0, "no volley at point blank")
