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


func test_elder_boar_charges_three_times_in_a_row() -> void:
	_add_walls()
	hero.position = Vector2(300, 200)
	hero.grant_iframes(30.0)
	var boar: Enemy = _enemy(&"elder_boar", Vector2(120, 200))
	var ai: ChargerAI = boar.ai
	watch_signals(boar)
	# Keep the hero in open floor so no charge ends on a wall: move to where the boar
	# is not aiming each time a lane locks.
	var charges: int = 0
	var was_charging: bool = false
	for i: int in 600:
		await wait_physics_frames(1)
		var charging: bool = ai.phase == ChargerAI.Phase.CHARGE
		if charging and not was_charging:
			charges += 1
		was_charging = charging
		if ai.phase == ChargerAI.Phase.RECOVER or ai.is_stunned():
			break
		if ai.phase == ChargerAI.Phase.CHARGE:
			hero.position = Vector2(192, 192) + (boar.global_position - Vector2(192, 192)).normalized().orthogonal() * 60.0
	assert_false(ai.is_stunned(), "no wall in the way")
	assert_eq(charges, 3, "Elder Boar charges 3 times before resting")


func test_elder_boar_wall_stun_ends_the_chain() -> void:
	_add_walls()
	hero.position = Vector2(300, 200)
	var boar: Enemy = _enemy(&"elder_boar", Vector2(160, 200))
	var ai: ChargerAI = boar.ai
	while ai.phase != ChargerAI.Phase.WINDUP:
		await wait_physics_frames(1)
	hero.position = Vector2(200, 330)
	for i: int in 120:
		await wait_physics_frames(1)
		if ai.is_stunned():
			break
	assert_true(ai.is_stunned(), "the first charge hit the east wall")
	await wait_seconds(boar.data.wall_stun + 0.1)
	assert_eq(ai.phase, ChargerAI.Phase.RECOVER, "no more charges after a stun")


func test_elites_have_a_gold_outline() -> void:
	var boar: Enemy = _enemy(&"elder_boar", Vector2(100, 100))
	var sprout: Enemy = _enemy(&"sproutling", Vector2(150, 100))
	assert_eq(boar.visual.outline_color, Enemy.ELITE_OUTLINE)
	assert_ne(sprout.visual.outline_color, Enemy.ELITE_OUTLINE)


func test_spore_witch_summons_sproutlings_the_director_counts() -> void:
	var encounter: EncounterData = EncounterData.new()
	var wave: WaveData = WaveData.new()
	wave.enemies.append(ContentDB.get_item(&"enemies", &"spore_witch"))
	encounter.waves.append(wave)
	var director: WaveDirector = WaveDirector.new()
	director.encounter = encounter
	director.spawn_points = [Vector2(100, 100)]
	director.spawn_warning = 0.05
	director.actors = world
	world.add_child(director)
	hero.position = Vector2(260, 100)
	hero.grant_iframes(30.0)
	await wait_seconds(0.2)
	var witch: Enemy = get_tree().get_nodes_in_group(Enemy.GROUP)[0]
	var ai: SummonerAI = witch.ai
	ai.summon_timer = 0.0
	ai.cooldown = 99.0
	# It may be finishing a spore cast first.
	for i: int in 180:
		if ai.phase == SummonerAI.Phase.SUMMON:
			break
		await wait_physics_frames(1)
	assert_eq(ai.phase, SummonerAI.Phase.SUMMON)
	await wait_seconds(witch.data.summon_windup + 0.1)
	assert_eq(ai.alive_minions(), witch.data.summon_count)
	assert_eq(director.tracker.alive, 1 + witch.data.summon_count)
	witch.health.take_damage(999)
	await wait_physics_frames(3)
	assert_false(director.is_room_cleared(), "summons must die too")
	# The sproutlings, then their seedlings.
	for i: int in 2:
		_kill_all_enemies()
		await wait_physics_frames(3)
	assert_true(director.is_room_cleared())


func test_spore_witch_stops_summoning_at_the_cap() -> void:
	var witch: Enemy = _enemy(&"spore_witch", Vector2(100, 100))
	hero.position = Vector2(360, 360)
	await wait_physics_frames(1)
	var ai: SummonerAI = witch.ai
	ai.summon_timer = 0.0
	for i: int in witch.data.summon_max_alive:
		ai.minions.append(_enemy(&"sproutling", Vector2(40 + i * 20, 40)))
	assert_false(ai.can_summon(), "4 alive is the cap")
	ai.minions[0].health.take_damage(999)
	assert_true(ai.can_summon())
	# Let the seedlings it split into join the world so they are freed with it.
	await wait_physics_frames(2)


func test_spore_cloud_lands_where_the_hero_stood() -> void:
	var witch: Enemy = _enemy(&"spore_witch", Vector2(100, 200))
	var ai: SummonerAI = witch.ai
	ai.summon_timer = 99.0
	hero.position = Vector2(260, 200)
	while ai.phase != SummonerAI.Phase.CAST:
		await wait_physics_frames(1)
	var target: Vector2 = hero.global_position
	hero.position = Vector2(260, 330)
	await wait_seconds(witch.data.attack.windup + 0.1)
	var clouds: Array[ThornPatch] = []
	for child: Node in world.get_children():
		if child is ThornPatch:
			clouds.append(child)
	assert_eq(clouds.size(), 1)
	if clouds.is_empty():
		return
	assert_almost_eq(clouds[0].global_position, target, Vector2(2, 2))
	assert_eq(hero.health.hp, hero.health.max_hp, "stepping away dodged it")
	hero.position = target
	await wait_seconds(0.2)
	assert_eq(hero.health.hp, hero.health.max_hp - 5, "spores hurt")


func _kill_all_enemies() -> void:
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		(node as Enemy).health.take_damage(999)
	await wait_physics_frames(1)
