extends GutTest
## Hero behavior driven by a scripted InputSource: combo, dodge, flasks, getting hit.

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero/hero.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/actors/training_dummy/training_dummy.tscn")
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


func test_steers_while_attacking() -> void:
	input.aim = Vector2.RIGHT
	input.move = Vector2.DOWN
	input.press(&"attack")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Attack"))
	await wait_physics_frames(10)
	assert_true(hero.state_machine.is_in(&"Attack"), "still swinging")
	assert_gt(hero.position.y, 110.0, "moved down during the swing")


func test_turns_toward_aim_while_swinging() -> void:
	input.aim = Vector2.RIGHT
	input.press(&"attack")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Attack"))
	input.aim = Vector2.DOWN
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Attack"), "still swinging")
	assert_eq(hero.facing, Vector2.DOWN, "the hero turns during the swing")
	assert_almost_eq(hero.weapon_pivot.rotation, 0.0, 0.01, "the strike stays where it was aimed")
	var first: AttackData = hero.weapon.combo[0]
	await wait_physics_frames(int((first.active + 0.08) * 60.0) + 2)
	assert_true(hero.state_machine.is_in(&"Attack"), "still in recovery")
	assert_almost_eq(hero.weapon_pivot.rotation, Vector2.DOWN.angle(), 0.01, "the weapon follows the aim after the strike")


func test_attack_move_scale_zero_roots_the_swing() -> void:
	hero.balance = hero.balance.duplicate()
	hero.balance.attack_move_scale = 0.0
	input.aim = Vector2.RIGHT
	input.move = Vector2.DOWN
	input.press(&"attack")
	await wait_physics_frames(12)
	assert_almost_eq(hero.position.y, 100.0, 0.5)


func test_slides_along_wall_at_a_shallow_angle() -> void:
	var room: Node2D = ROOM_SCRIPT.new()
	room.set("size_tiles", Vector2i(12, 12))
	world.add_child(room)
	hero.position = Vector2(100, 40)
	# Mostly into the top wall, a little to the right (about 11 degrees).
	input.move = Vector2(0.2, -1.0).normalized()
	await wait_physics_frames(60)
	assert_gt(hero.position.x, 110.0, "slides instead of sticking")


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



func test_each_combo_step_slashes_its_own_way() -> void:
	var combo: Array[AttackData] = hero.weapon.combo
	assert_eq(combo[0].slash_sweep, 1.0)
	assert_eq(combo[1].slash_sweep, -1.0, "the second swing comes back the other way")
	assert_gt(combo[2].slash_arc, combo[0].slash_arc, "the finisher is the widest")


func test_the_slash_sweeps_then_fades() -> void:
	var arc: SwingArc = SwingArc.new()
	add_child_autofree(arc)
	arc.play(20.0, 4.0, 0.2, -1.0, 1.2)
	var start: Vector2 = arc.drawn_span()
	assert_almost_eq(start.y - start.x, 0.0, 0.001, "nothing drawn yet")
	arc._process(0.06)
	var mid: Vector2 = arc.drawn_span()
	assert_almost_eq(mid.y, 1.2, 0.001, "a backward sweep starts on the other side")
	assert_lt(mid.x, 1.2)
	assert_gt(mid.x, -1.2)
	arc._process(0.1)
	assert_eq(arc.drawn_span(), Vector2(-1.2, 1.2), "the whole arc once the sweep ends")
	arc._process(0.1)
	assert_false(arc.is_playing())


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


# --- Gamepad feel (M1 PR 3) --------------------------------------------------

func test_stick_attack_turns_toward_close_target() -> void:
	_add_dummy(Vector2(140, 100))
	input.aim_assist = true
	input.aim = Vector2.RIGHT.rotated(deg_to_rad(25))
	input.press(&"attack")
	await wait_physics_frames(3)
	assert_almost_eq(hero.weapon_pivot.rotation, 0.0, 0.01)


func test_mouse_attack_is_not_assisted() -> void:
	_add_dummy(Vector2(140, 100))
	input.aim_assist = false
	input.aim = Vector2.RIGHT.rotated(deg_to_rad(25))
	input.press(&"attack")
	await wait_physics_frames(3)
	assert_almost_eq(hero.weapon_pivot.rotation, deg_to_rad(25), 0.01)


func test_hits_and_getting_hit_rumble() -> void:
	var dummy: TrainingDummy = _add_dummy(Vector2(122, 100))
	input.aim = Vector2.RIGHT
	input.press(&"attack")
	await wait_physics_frames(20)
	assert_lt(dummy.health.hp, dummy.health.max_hp)
	assert_gt(input.last_rumble.x, 0.0, "landing a hit rumbles")
	input.last_rumble = Vector2.ZERO
	var slam: AttackData = AttackData.new()
	slam.damage = 5.0
	var hitbox: HitboxComponent = HitboxComponent.new()
	hitbox.attack = slam
	world.add_child(hitbox)
	hero.hurtbox.receive_hit(hitbox)
	# Scaled by the tuned rumble_strength in balance_default.tres.
	assert_almost_eq(input.last_rumble.x, Hero.HURT_RUMBLE.x * hero.balance.rumble_strength, 0.001)


func test_light_rumbles_are_raised_until_a_pad_can_feel_them() -> void:
	assert_eq(LocalInputSource.motor_levels(0.0, 0.2), Vector3.ZERO, "zero stays off")
	var tap: Vector3 = LocalInputSource.motor_levels(0.12, 0.06)
	assert_almost_eq(tap.y, LocalInputSource.MIN_RUMBLE, 0.001, "a light tap is raised to the weakest felt rumble")
	assert_almost_eq(tap.z, LocalInputSource.MIN_RUMBLE_TIME, 0.001, "and lasts long enough to feel")
	var hurt: Vector3 = LocalInputSource.motor_levels(0.6, 0.18)
	assert_almost_eq(hurt.y, 0.6, 0.001, "the strong motor carries the hit")
	assert_lt(hurt.x, hurt.y)
	assert_almost_eq(LocalInputSource.motor_levels(5.0, 0.2).y, 1.0, 0.001, "capped at full")


func test_rumble_strength_zero_turns_it_off() -> void:
	var old: float = hero.balance.rumble_strength
	hero.balance.rumble_strength = 0.0
	hero.rumble(0.8, 0.1)
	hero.balance.rumble_strength = old
	assert_eq(input.last_rumble.x, 0.0)


func test_dodge_without_stamina_is_denied() -> void:
	watch_signals(hero)
	hero.stamina.current = 5.0
	input.press(&"dodge")
	await wait_physics_frames(2)
	assert_signal_emitted(hero, "dodge_denied")
	assert_true(hero.state_machine.is_in(&"Move"))


func test_apply_balance_updates_stamina_regen() -> void:
	var tuned: BalanceData = hero.balance.duplicate()
	tuned.stamina_regen = 99.0
	hero.balance = tuned
	hero.apply_balance()
	assert_eq(hero.stamina.regen_per_second, 99.0)


func test_steer_reverses_as_fast_as_it_stops() -> void:
	var tuning: BalanceData = BalanceData.new()
	var turned: Vector2 = Hero.steer(Vector2(100, 0), Vector2(-100, 0), tuning, 0.01)
	assert_almost_eq(turned.x, 100.0 - (tuning.hero_acceleration + tuning.hero_friction) * 0.01, 0.01)
	var sped_up: Vector2 = Hero.steer(Vector2.ZERO, Vector2(100, 0), tuning, 0.01)
	assert_almost_eq(sped_up.x, tuning.hero_acceleration * 0.01, 0.01)
	var stopped: Vector2 = Hero.steer(Vector2(100, 0), Vector2.ZERO, tuning, 0.01)
	assert_almost_eq(stopped.x, 100.0 - tuning.hero_friction * 0.01, 0.01)


func test_turning_around_is_quick() -> void:
	input.move = Vector2.RIGHT
	await wait_physics_frames(20)
	input.move = Vector2.LEFT
	await wait_physics_frames(6)
	assert_lt(hero.velocity.x, -50.0, "already running the other way after 0.1 s")


func test_attack_keeps_running_momentum() -> void:
	input.move = Vector2.RIGHT
	await wait_physics_frames(20)
	input.aim = Vector2.RIGHT
	input.press(&"attack")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Attack"))
	var old_snap: float = hero.weapon.combo[0].lunge_speed + hero.balance.hero_move_speed * hero.balance.attack_move_scale
	assert_gt(hero.velocity.x, old_snap, "no sudden stop at the start of the swing")


func test_small_stick_tilt_keeps_facing() -> void:
	hero.facing = Vector2.RIGHT
	input.move = Vector2(0, 0.3)
	await wait_physics_frames(3)
	assert_eq(hero.facing, Vector2.RIGHT, "a stick drifting back to center does not turn the hero")
	input.move = Vector2.DOWN
	await wait_physics_frames(2)
	assert_eq(hero.facing, Vector2.DOWN)


func test_attack_pressed_during_finisher_starts_next_combo() -> void:
	input.aim = Vector2.RIGHT
	hero.combo_step = hero.weapon.combo.size() - 1
	hero.combo_timer = 1.0
	input.press(&"attack")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Attack"))
	# Press near the end of the finisher's recovery, inside the input buffer.
	var finisher: AttackData = hero.weapon.combo[-1]
	var frames: int = int((finisher.windup + finisher.active + finisher.recovery) * 60.0)
	await wait_physics_frames(frames - 5)
	input.press(&"attack")
	await wait_physics_frames(10)
	assert_true(hero.state_machine.is_in(&"Attack"), "the press was kept, not swallowed")
	assert_eq(hero.combo_step, 0, "a new combo starts at the first swing")


func test_released_right_stick_keeps_aim_briefly() -> void:
	var local: LocalInputSource = autofree(LocalInputSource.new())
	assert_eq(local.stick_aim(Vector2(0.9, 0), 1000), Vector2.RIGHT)
	assert_eq(local.stick_aim(Vector2.ZERO, 1000 + LocalInputSource.STICK_AIM_HOLD_MSEC - 50), Vector2.RIGHT)
	assert_eq(local.stick_aim(Vector2.ZERO, 1000 + LocalInputSource.STICK_AIM_HOLD_MSEC + 50), Vector2.ZERO)
