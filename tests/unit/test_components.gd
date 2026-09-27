extends GutTest
## Health, Knockback, Status and StateMachine components.


class CountingState:
	extends State
	var entered: int = 0
	var exited: int = 0
	var updates: int = 0

	func enter(_msg: Dictionary = {}) -> void:
		entered += 1

	func exit() -> void:
		exited += 1

	func physics_update(_delta: float) -> void:
		updates += 1


func _make_health(max_hp: int) -> HealthComponent:
	var health: HealthComponent = HealthComponent.new()
	health.max_hp = max_hp
	add_child_autofree(health)
	return health


func test_health_takes_damage_and_dies_once() -> void:
	var health: HealthComponent = _make_health(30)
	watch_signals(health)
	assert_eq(health.take_damage(10), 10)
	assert_eq(health.hp, 20)
	assert_eq(health.take_damage(50), 20, "only what is left is taken")
	assert_true(health.is_dead())
	assert_eq(health.take_damage(5), 0, "no damage after death")
	assert_signal_emit_count(health, "died", 1)


func test_health_heal_caps_at_max_and_not_when_dead() -> void:
	var health: HealthComponent = _make_health(100)
	health.take_damage(30)
	assert_eq(health.heal(50), 30)
	assert_eq(health.hp, 100)
	health.take_damage(100)
	assert_eq(health.heal(10), 0)


func test_health_set_max_hp() -> void:
	var health: HealthComponent = _make_health(100)
	health.set_max_hp(60)
	assert_eq(health.hp, 60, "hp clamps to new max")
	health.set_max_hp(120, true)
	assert_eq(health.hp, 120)


func test_knockback_fades_to_zero() -> void:
	var kb: KnockbackComponent = KnockbackComponent.new()
	autofree(kb)
	kb.friction = 1000.0
	kb.apply(Vector2(200, 0))
	assert_true(kb.is_active())
	kb.tick(0.1)
	assert_almost_eq(kb.velocity.x, 100.0, 0.001)
	kb.tick(0.2)
	assert_false(kb.is_active())


func test_knockback_weight_scale() -> void:
	var kb: KnockbackComponent = KnockbackComponent.new()
	autofree(kb)
	kb.weight_scale = 0.5
	kb.apply(Vector2(0, 100))
	assert_eq(kb.velocity, Vector2(0, 50))


func test_status_stacks_refreshes_and_expires() -> void:
	var status: StatusComponent = StatusComponent.new()
	autofree(status)
	watch_signals(status)
	status.apply(&"burn", 4.0, 3)
	status.apply(&"burn", 2.0, 3)
	assert_eq(status.stacks(&"burn"), 2)
	status.tick(3.9)
	assert_true(status.has(&"burn"), "longest duration is kept")
	status.tick(0.2)
	assert_false(status.has(&"burn"))
	assert_signal_emit_count(status, "status_added", 1)
	assert_signal_emit_count(status, "status_removed", 1)


func test_status_stack_cap() -> void:
	var status: StatusComponent = StatusComponent.new()
	autofree(status)
	for i: int in 5:
		status.apply(&"chill", 1.0, 3)
	assert_eq(status.stacks(&"chill"), 3)


func test_state_machine_starts_and_transitions() -> void:
	var machine: StateMachine = StateMachine.new()
	var a: CountingState = CountingState.new()
	a.name = "A"
	var b: CountingState = CountingState.new()
	b.name = "B"
	machine.add_child(a)
	machine.add_child(b)
	machine.initial_state = a
	add_child_autofree(machine)
	var actor: Node = autofree(Node.new())
	machine.start(actor)
	assert_eq(a.entered, 1)
	assert_eq(a.actor, actor)
	machine.physics_update(0.016)
	assert_eq(a.updates, 1)
	machine.transition_to(&"B")
	assert_eq(a.exited, 1)
	assert_eq(b.entered, 1)
	assert_true(machine.is_in(&"B"))
	machine.physics_update(0.016)
	assert_eq(b.updates, 1)
	assert_eq(a.updates, 1)


func test_hit_stop_always_restores_time_scale() -> void:
	HitStop.enabled = true
	# Overlapping, extending and shorter requests, like a crit right after a heavy hit.
	HitStop.request(get_tree(), 0.05)
	HitStop.request(get_tree(), 0.08)
	HitStop.request(get_tree(), 0.02)
	assert_eq(Engine.time_scale, HitStop.frozen_scale)
	# Physics frames tick in real time, so 20 frames is about 0.33 s.
	await wait_physics_frames(20)
	assert_eq(Engine.time_scale, 1.0)
	for i: int in 10:
		HitStop.request(get_tree(), 0.001 * (i + 1))
		await wait_physics_frames(1)
	await wait_physics_frames(10)
	assert_eq(Engine.time_scale, 1.0, "never left frozen")


func test_hit_stop_disabled_does_nothing() -> void:
	HitStop.enabled = false
	HitStop.request(get_tree(), 0.5)
	assert_eq(Engine.time_scale, 1.0)
	HitStop.enabled = true
