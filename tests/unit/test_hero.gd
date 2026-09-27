extends GutTest
## Hero behavior driven by a scripted InputSource: combo, dodge, flasks, getting hit.

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero/hero.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/actors/training_dummy/training_dummy.tscn")

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
	hero.position = Vector2(100, 100)
	world.add_child(hero)
	hero.stats.crit_chance = 0.0


func after_each() -> void:
	HitStop.enabled = true
	Engine.time_scale = 1.0


func _add_dummy(pos: Vector2, slam: AttackData = null) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.counterattack = slam
	dummy.position = pos
	world.add_child(dummy)
	return dummy


func test_hero_uses_scripted_input_and_content_defaults() -> void:
	assert_eq(hero.input, input)
	assert_not_null(hero.weapon, "sword loads from ContentDB")
	assert_eq(hero.weapon.combo.size(), 3)
	assert_eq(hero.health.max_hp, hero.balance.hero_max_hp)
	assert_true(hero.state_machine.is_in(&"Move"))


func test_moves_with_input() -> void:
	input.move = Vector2.DOWN
	await wait_physics_frames(30)
	assert_gt(hero.position.y, 120.0)
	assert_almost_eq(hero.position.x, 100.0, 0.5)


func test_single_attack_hits_dummy_once() -> void:
	var dummy: TrainingDummy = _add_dummy(Vector2(122, 100))
	input.aim = Vector2.RIGHT
	input.press(&"attack")
	await wait_physics_frames(30)
	assert_eq(dummy.health.hp, dummy.health.max_hp - 12)
	assert_eq(hero.combo_step, 1, "next press continues the combo")


func test_three_hit_combo_deals_12_12_20() -> void:
	var dummy: TrainingDummy = _add_dummy(Vector2(122, 100))
	input.aim = Vector2.RIGHT
	input.press(&"attack")
	await wait_physics_frames(6)
	input.press(&"attack")
	await wait_physics_frames(12)
	input.press(&"attack")
	await wait_physics_frames(45)
	assert_eq(dummy.health.hp, dummy.health.max_hp - 44)
	assert_eq(hero.combo_step, 0, "combo wraps after the finisher")
	assert_true(hero.state_machine.is_in(&"Move"))


func test_attack_misses_when_aiming_away() -> void:
	var dummy: TrainingDummy = _add_dummy(Vector2(122, 100))
	input.aim = Vector2.LEFT
	input.press(&"attack")
	await wait_physics_frames(30)
	assert_eq(dummy.health.hp, dummy.health.max_hp)


func test_dodge_spends_stamina_grants_iframes_and_travels() -> void:
	input.move = Vector2.RIGHT
	input.press(&"dodge")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Dodge"))
	assert_true(hero.hurtbox.invincible)
	assert_eq(hero.stamina.current, hero.balance.hero_max_stamina - hero.balance.dodge_stamina_cost)
	await wait_physics_frames(20)
	assert_gt(hero.position.x, 160.0)


func test_no_dodge_without_stamina() -> void:
	hero.stamina.try_spend(90.0)
	input.press(&"dodge")
	await wait_physics_frames(2)
	assert_false(hero.state_machine.is_in(&"Dodge"))


func test_dodge_cancels_attack_recovery() -> void:
	input.aim = Vector2.RIGHT
	input.press(&"attack")
	await wait_physics_frames(10)
	input.press(&"dodge")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Dodge"))


func test_flask_heals_after_drinking() -> void:
	hero.health.take_damage(50)
	await wait_physics_frames(15)
	input.press(&"flask")
	await wait_physics_frames(35)
	assert_eq(hero.health.hp, 85)
	assert_eq(hero.flasks.charges, hero.balance.flask_charges - 1)


func test_flask_ignored_at_full_hp() -> void:
	input.press(&"flask")
	await wait_physics_frames(5)
	assert_false(hero.state_machine.is_in(&"Drink"))
	assert_eq(hero.flasks.charges, hero.balance.flask_charges)


func test_sparring_dummy_slam_hurts_hero() -> void:
	var slam: AttackData = AttackData.new()
	slam.damage = 10.0
	slam.windup = 0.2
	slam.active = 0.1
	slam.radius = 40.0
	slam.knockback = 150.0
	_add_dummy(Vector2(125, 100), slam)
	await wait_physics_frames(25)
	assert_eq(hero.health.hp, hero.health.max_hp - 10)
	assert_true(hero.has_iframes(), "grace period after a hit")


func test_iframes_block_the_slam() -> void:
	var slam: AttackData = AttackData.new()
	slam.damage = 10.0
	slam.windup = 0.2
	slam.active = 0.1
	slam.radius = 40.0
	hero.grant_iframes(5.0)
	_add_dummy(Vector2(125, 100), slam)
	await wait_physics_frames(25)
	assert_eq(hero.health.hp, hero.health.max_hp)


func test_death_reports_on_event_bus() -> void:
	watch_signals(EventBus)
	hero.health.take_damage(999)
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Dead"))
	assert_signal_emitted_with_parameters(EventBus, "hero_died", [hero.player_id])


func test_training_dummy_revives_after_dying() -> void:
	var dummy: TrainingDummy = _add_dummy(Vector2(300, 300))
	dummy.health.take_damage(9999)
	assert_true(dummy.health.is_dead())
	await wait_physics_frames(30)
	assert_eq(dummy.health.hp, dummy.health.max_hp)
