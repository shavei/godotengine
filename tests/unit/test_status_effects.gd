extends GutTest
## StatusEffects (docs/GDD.md Section 7.3): burn, chill and freeze, root, stagger, and
## the boss rules.

var balance: BalanceData


func before_each() -> void:
	balance = BalanceData.new()


func _ticks(effects: StatusEffects, seconds: float, step: float = 0.1) -> int:
	var damage: int = 0
	var steps: int = roundi(seconds / step)
	for i: int in steps:
		damage += effects.tick(step)
	return damage


func test_burn_deals_damage_per_stack_every_second() -> void:
	var effects: StatusEffects = StatusEffects.new(balance)
	effects.apply(StatusEffects.BURN)
	assert_eq(effects.tick(0.5), 0)
	assert_eq(effects.tick(0.5), 3, "first tick after a second")
	effects.apply(StatusEffects.BURN)
	assert_eq(effects.stacks(StatusEffects.BURN), 2)
	assert_eq(effects.tick(1.0), 6)


func test_burn_stacks_cap_at_three_and_runs_out() -> void:
	var effects: StatusEffects = StatusEffects.new(balance)
	for i: int in 5:
		effects.apply(StatusEffects.BURN)
	assert_eq(effects.stacks(StatusEffects.BURN), 3)
	var total: int = _ticks(effects, 5.0, 0.25)
	assert_eq(total, 36, "3 stacks x 3 damage x 4 seconds")
	assert_false(effects.has(StatusEffects.BURN))


func test_chill_slows_moving_and_acting() -> void:
	var effects: StatusEffects = StatusEffects.new(balance)
	effects.apply(StatusEffects.CHILL)
	assert_almost_eq(effects.move_scale(), 0.7, 0.001)
	assert_almost_eq(effects.action_scale(), 0.7, 0.001)
	_ticks(effects, 3.1)
	assert_false(effects.has(StatusEffects.CHILL))
	assert_eq(effects.move_scale(), 1.0)


func test_three_chills_freeze() -> void:
	var effects: StatusEffects = StatusEffects.new(balance)
	watch_signals(effects)
	effects.apply(StatusEffects.CHILL)
	effects.apply(StatusEffects.CHILL)
	assert_false(effects.has(StatusEffects.FREEZE))
	effects.apply(StatusEffects.CHILL)
	assert_true(effects.has(StatusEffects.FREEZE))
	assert_false(effects.has(StatusEffects.CHILL), "chill becomes the freeze")
	assert_true(effects.is_held())
	assert_eq(effects.move_scale(), 0.0)
	assert_eq(effects.action_scale(), 0.0)
	effects.apply(StatusEffects.CHILL)
	assert_false(effects.has(StatusEffects.CHILL), "no chill while frozen")
	_ticks(effects, 1.6)
	assert_false(effects.is_held())


func test_three_shards_at_once_freeze() -> void:
	var effects: StatusEffects = StatusEffects.new(balance)
	effects.apply(StatusEffects.CHILL, 3)
	assert_true(effects.has(StatusEffects.FREEZE))


func test_root_stops_moving_but_not_acting() -> void:
	var effects: StatusEffects = StatusEffects.new(balance)
	effects.apply(StatusEffects.ROOT)
	assert_eq(effects.move_scale(), 0.0)
	assert_eq(effects.action_scale(), 1.0)
	assert_false(effects.is_held())
	_ticks(effects, 2.1)
	assert_false(effects.has(StatusEffects.ROOT))


func test_full_stagger_bar_stuns_and_empties() -> void:
	var effects: StatusEffects = StatusEffects.new(balance)
	watch_signals(effects)
	effects.add_stagger(40.0)
	assert_almost_eq(effects.stagger_fraction(), 40.0 / 60.0, 0.001)
	assert_false(effects.has(StatusEffects.STUN))
	effects.add_stagger(20.0)
	assert_true(effects.has(StatusEffects.STUN))
	assert_signal_emitted(effects, "staggered")
	assert_eq(effects.stagger, 0.0)
	effects.add_stagger(100.0)
	assert_eq(effects.stagger, 0.0, "no build-up while stunned")
	_ticks(effects, 1.6)
	assert_false(effects.is_held())


func test_bosses_have_shorter_statuses_and_a_bigger_bar() -> void:
	var effects: StatusEffects = StatusEffects.new(balance, true)
	effects.apply(StatusEffects.BURN)
	assert_almost_eq(effects.time_left(StatusEffects.BURN), 2.0, 0.001)
	effects.add_stagger(100.0)
	assert_false(effects.has(StatusEffects.STUN), "a regular enemy's bar is 60, a boss's 250")
	effects.add_stagger(150.0)
	assert_almost_eq(effects.time_left(StatusEffects.STUN), 0.75, 0.001)


func test_bosses_cannot_be_frozen_chill_fills_stagger_instead() -> void:
	var effects: StatusEffects = StatusEffects.new(balance, true)
	effects.apply(StatusEffects.CHILL, 3)
	assert_false(effects.has(StatusEffects.FREEZE))
	assert_eq(effects.stagger, balance.boss_freeze_stagger)


func test_bosses_cannot_be_rooted_root_fills_stagger_once_per_window() -> void:
	var effects: StatusEffects = StatusEffects.new(balance, true)
	effects.apply(StatusEffects.ROOT)
	effects.apply(StatusEffects.ROOT)
	assert_false(effects.has(StatusEffects.ROOT))
	assert_eq(effects.stagger, balance.boss_root_stagger, "a patch pulsing on a boss adds once per window")
	_ticks(effects, 1.1)
	effects.apply(StatusEffects.ROOT)
	assert_eq(effects.stagger, balance.boss_root_stagger * 2.0)


func test_clear_removes_everything() -> void:
	var effects: StatusEffects = StatusEffects.new(balance)
	effects.apply(StatusEffects.BURN)
	effects.apply(StatusEffects.ROOT)
	effects.add_stagger(10.0)
	effects.clear()
	assert_eq(effects.active_ids().size(), 0)
	assert_eq(effects.stagger, 0.0)
