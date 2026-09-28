extends GutTest
## StaminaPool and FlaskPouch rules (docs/GDD.md Sections 6.3 and 7.2).


func test_spend_needs_enough_stamina() -> void:
	var pool: StaminaPool = StaminaPool.new(100.0, 40.0, 0.5)
	for i: int in 4:
		assert_true(pool.try_spend(25.0))
	assert_eq(pool.current, 0.0)
	assert_false(pool.try_spend(25.0))
	assert_eq(pool.current, 0.0, "a failed spend takes nothing")


func test_unlimited_stamina_never_runs_out() -> void:
	var pool: StaminaPool = StaminaPool.new(100.0, 40.0, 0.5)
	pool.unlimited = true
	for i: int in 10:
		assert_true(pool.try_spend(25.0))
	assert_eq(pool.current, 100.0, "nothing is taken")


func test_regen_waits_for_delay_then_refills() -> void:
	var pool: StaminaPool = StaminaPool.new(100.0, 40.0, 0.5)
	pool.try_spend(50.0)
	pool.tick(0.4)
	assert_eq(pool.current, 50.0, "no regen during the delay")
	pool.tick(0.35)
	# 0.1 s of delay left, then 0.25 s of regen at 40/s = 10.
	assert_almost_eq(pool.current, 60.0, 0.001)
	pool.tick(5.0)
	assert_eq(pool.current, 100.0, "regen stops at max")


func test_spending_resets_the_delay() -> void:
	var pool: StaminaPool = StaminaPool.new(100.0, 40.0, 0.5)
	pool.try_spend(25.0)
	pool.tick(0.45)
	pool.try_spend(25.0)
	pool.tick(0.45)
	assert_eq(pool.current, 50.0)


func test_stamina_signals_changes() -> void:
	var pool: StaminaPool = StaminaPool.new()
	watch_signals(pool)
	pool.try_spend(10.0)
	assert_signal_emitted_with_parameters(pool, "changed", [90.0, 100.0])


func test_flask_heals_a_share_of_max_hp() -> void:
	var pouch: FlaskPouch = FlaskPouch.new(3, 0.35)
	assert_eq(pouch.drink(50, 100), 35)
	assert_eq(pouch.charges, 2)


func test_flask_not_wasted_at_full_hp_or_when_dead() -> void:
	var pouch: FlaskPouch = FlaskPouch.new(3, 0.35)
	assert_eq(pouch.drink(100, 100), 0)
	assert_eq(pouch.drink(0, 100), 0)
	assert_eq(pouch.charges, 3)


func test_flask_runs_out_and_refills() -> void:
	var pouch: FlaskPouch = FlaskPouch.new(3, 0.35)
	for i: int in 3:
		pouch.drink(10, 100)
	assert_eq(pouch.charges, 0)
	assert_false(pouch.can_drink(10, 100))
	pouch.refill(1)
	assert_eq(pouch.charges, 1)
	pouch.refill()
	assert_eq(pouch.charges, 3)
