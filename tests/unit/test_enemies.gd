extends GutTest
## Enemy behavior against a scripted hero: telegraphs, attacks, splits, wall stuns,
## arrows and thorn patches, and wave clears.

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero/hero.tscn")
const ROOM_SCRIPT: Script = preload("res://scenes/run/placeholder_room.gd")

var world: Node2D
var hero: Hero
var input: InputSource


func before_each() -> void:
	HitStop.enabled = false
	world = Node2D.new()
	add_child_autofree(world)
	hero = HERO_SCENE.instantiate()
	input = InputSource.new()
	input.name = "ScriptedInput"
	hero.add_child(input)
	hero.position = Vector2(200, 200)
	world.add_child(hero)
	hero.stats.crit_chance = 0.0


func after_each() -> void:
	HitStop.enabled = true
	Engine.time_scale = 1.0


func _enemy(id: StringName, pos: Vector2) -> Enemy:
	var enemy: Enemy = Enemy.create(ContentDB.get_item(&"enemies", id))
	enemy.position = pos
	world.add_child(enemy)
	return enemy


## A walled room (12 x 12 tiles, 384 px) behind the actors.
func _add_walls() -> void:
	var room: Node2D = ROOM_SCRIPT.new()
	room.set("size_tiles", Vector2i(12, 12))
	world.add_child(room)


func test_enemy_applies_its_data() -> void:
	var boar: Enemy = _enemy(&"tusk_boar", Vector2(50, 50))
	assert_eq(boar.health.max_hp, 60)
	assert_eq(boar.knockback.weight_scale, 0.25)
	assert_true(boar.ai is ChargerAI)
	assert_true(boar.is_in_group(Enemy.GROUP))


func test_sproutling_chases_telegraphs_then_bites() -> void:
	var sprout: Enemy = _enemy(&"sproutling", Vector2(260, 200))
	watch_signals(sprout)
	await wait_physics_frames(30)
	assert_lt(sprout.position.x, 255.0, "walks toward the hero")
	# Walk in, 0.45 s telegraph, bite.
	await wait_seconds(1.6)
	assert_signal_emitted(sprout, "telegraph_started")
	assert_lt(hero.health.hp, hero.health.max_hp, "the bite landed")


func test_dodge_iframes_avoid_the_bite() -> void:
	var sprout: Enemy = _enemy(&"sproutling", Vector2(220, 200))
	sprout.ai.cooldown = 0.0
	await wait_physics_frames(2)
	# Hold i-frames through the whole wind-up and bite.
	for i: int in 60:
		hero.grant_iframes(0.1)
		await wait_physics_frames(1)
	assert_eq(hero.health.hp, hero.health.max_hp)
	assert_true(sprout.ai is SwarmAI)


func test_sproutling_splits_into_two_seedlings() -> void:
	var sprout: Enemy = _enemy(&"sproutling", Vector2(320, 320))
	var children: Array[Enemy] = []
	sprout.spawned.connect(func(child: Enemy) -> void: children.append(child))
	sprout.health.take_damage(999)
	await wait_physics_frames(3)
	assert_eq(children.size(), 2)
	for child: Enemy in children:
		assert_true(is_instance_valid(child) and child.is_inside_tree())
		assert_eq(child.data.id, &"seedling")
	assert_true(sprout.is_dead())
	await wait_seconds(0.6)
	assert_false(is_instance_valid(sprout), "freed after the death animation")


func test_seedlings_do_not_split_again() -> void:
	var seedling: Enemy = _enemy(&"seedling", Vector2(320, 320))
	watch_signals(seedling)
	seedling.health.take_damage(999)
	await wait_physics_frames(3)
	assert_signal_not_emitted(seedling, "spawned")
	assert_signal_emitted(seedling, "died")


func test_hero_sword_kills_seedling() -> void:
	var seedling: Enemy = _enemy(&"seedling", Vector2(218, 200))
	watch_signals(seedling)
	input.aim = Vector2.RIGHT
	input.press(&"attack")
	await wait_physics_frames(20)
	assert_signal_emitted(seedling, "died", "12 damage beats 8 HP")


func test_boar_charges_and_hits_hero() -> void:
	_add_walls()
	hero.position = Vector2(300, 200)
	_enemy(&"tusk_boar", Vector2(160, 200))
	await wait_seconds(1.5)
	assert_lt(hero.health.hp, hero.health.max_hp, "the charge landed")


func test_boar_stuns_itself_on_a_wall() -> void:
	_add_walls()
	hero.position = Vector2(300, 200)
	var boar: Enemy = _enemy(&"tusk_boar", Vector2(160, 200))
	var ai: ChargerAI = boar.ai
	# Wait for the lane to lock, then step out of it.
	while ai.phase != ChargerAI.Phase.WINDUP:
		await wait_physics_frames(1)
	hero.position = Vector2(200, 330)
	var stunned: bool = false
	for i: int in 90:
		await wait_physics_frames(1)
		if ai.is_stunned():
			stunned = true
			break
	assert_true(stunned, "charged into the east wall")
	assert_eq(hero.health.hp, hero.health.max_hp)


func test_hits_do_not_interrupt_a_boar() -> void:
	var boar: Enemy = _enemy(&"tusk_boar", Vector2(260, 200))
	var ai: ChargerAI = boar.ai
	while ai.phase != ChargerAI.Phase.WINDUP:
		await wait_physics_frames(1)
	input.aim = Vector2.RIGHT
	hero.position = Vector2(240, 200)
	input.press(&"attack")
	await wait_physics_frames(8)
	assert_lt(boar.health.hp, boar.health.max_hp)
	assert_ne(ai.phase, ChargerAI.Phase.RECOVER, "kept its charge going")


func test_archer_arrow_hits_hero() -> void:
	_enemy(&"thorn_archer", Vector2(330, 200))
	await wait_seconds(1.5)
	assert_lt(hero.health.hp, hero.health.max_hp)


func test_missed_arrow_leaves_thorn_patch_that_hurts() -> void:
	_add_walls()
	var archer: Enemy = _enemy(&"thorn_archer", Vector2(100, 200))
	var ai: RangedAI = archer.ai
	hero.position = Vector2(230, 200)
	while ai.phase != RangedAI.Phase.WINDUP:
		await wait_physics_frames(1)
	# Step out of the lane; the arrow flies on into the east wall.
	hero.position = Vector2(230, 300)
	# 0.6 s wind-up, then about 1.3 s of flight.
	await wait_seconds(2.0)
	var patches: Array[ThornPatch] = []
	for child: Node in world.get_children():
		if child is ThornPatch:
			patches.append(child)
	assert_eq(patches.size(), 1)
	assert_eq(hero.health.hp, hero.health.max_hp, "the arrow missed")
	if patches.is_empty():
		return
	hero.position = patches[0].global_position
	archer.health.take_damage(999)
	await wait_seconds(0.3)
	assert_eq(hero.health.hp, hero.health.max_hp - 4, "thorns hurt")


func test_wave_director_clears_room_including_splits() -> void:
	var encounter: EncounterData = EncounterData.new()
	encounter.wave_delay = 0.1
	for id: StringName in [&"sproutling", &"seedling"]:
		var wave: WaveData = WaveData.new()
		wave.enemies.append(ContentDB.get_item(&"enemies", id))
		encounter.waves.append(wave)
	var director: WaveDirector = WaveDirector.new()
	director.encounter = encounter
	director.spawn_points = [Vector2(20, 20)]
	director.spawn_warning = 0.1
	director.rng_seed = 7
	director.actors = world
	watch_signals(director)
	world.add_child(director)
	hero.position = Vector2(400, 400)
	await wait_seconds(0.3)
	assert_signal_emitted_with_parameters(director, "wave_started", [0, 2])
	# Kill wave 1: the Sproutling and then its 2 seedlings.
	await _kill_all_enemies()
	await wait_physics_frames(3)
	assert_signal_not_emitted(director, "wave_cleared", "seedlings still alive")
	await _kill_all_enemies()
	await wait_physics_frames(3)
	assert_signal_emitted_with_parameters(director, "wave_cleared", [0])
	await wait_seconds(0.4)
	assert_signal_emitted_with_parameters(director, "wave_started", [1, 2])
	await _kill_all_enemies()
	await wait_physics_frames(3)
	assert_signal_emitted(director, "room_cleared")
	assert_true(director.is_room_cleared())


func _kill_all_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(node as Enemy).health.take_damage(999)
	await wait_physics_frames(1)
