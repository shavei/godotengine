extends GutTest
## CombatMath: damage formula, crits and the armor cap (docs/GDD.md Section 7.2).

var rng: RandomNumberGenerator


func before_each() -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = 1234


func test_plain_hit_deals_base_damage() -> void:
	var result: DamageResult = CombatMath.damage(12.0, CombatStats.new(), CombatStats.new(), rng)
	assert_eq(result.amount, 12)
	assert_false(result.is_crit)


func test_weapon_tier_and_bonus_multiply() -> void:
	var attacker: CombatStats = CombatStats.new()
	attacker.weapon_tier = 1.3
	attacker.damage_bonus = 0.5
	# 20 * 1.3 * 1.5 = 39
	assert_eq(CombatMath.damage(20.0, attacker, CombatStats.new(), rng).amount, 39)


func test_forced_crit_uses_multiplier() -> void:
	var attacker: CombatStats = CombatStats.new()
	attacker.crit_multiplier = 1.5
	var result: DamageResult = CombatMath.damage(20.0, attacker, CombatStats.new(), rng, true)
	assert_true(result.is_crit)
	assert_eq(result.amount, 30)


func test_crit_chance_zero_never_crits_and_one_always_crits() -> void:
	var never: CombatStats = CombatStats.new()
	never.crit_chance = 0.0
	var always: CombatStats = CombatStats.new()
	always.crit_chance = 1.0
	for i: int in 50:
		assert_false(CombatMath.damage(10.0, never, CombatStats.new(), rng).is_crit)
		assert_true(CombatMath.damage(10.0, always, CombatStats.new(), rng).is_crit)


func test_crit_rate_is_roughly_the_chance() -> void:
	var attacker: CombatStats = CombatStats.new()
	attacker.crit_chance = 0.05
	var crits: int = 0
	for i: int in 4000:
		if CombatMath.damage(10.0, attacker, CombatStats.new(), rng).is_crit:
			crits += 1
	assert_between(crits, 140, 260, "about 5% of 4000")


func test_same_seed_gives_same_results() -> void:
	var attacker: CombatStats = CombatStats.new()
	attacker.crit_chance = 0.5
	var a: RandomNumberGenerator = RandomNumberGenerator.new()
	var b: RandomNumberGenerator = RandomNumberGenerator.new()
	a.seed = 99
	b.seed = 99
	for i: int in 20:
		var ra: DamageResult = CombatMath.damage(10.0, attacker, CombatStats.new(), a)
		var rb: DamageResult = CombatMath.damage(10.0, attacker, CombatStats.new(), b)
		assert_eq(ra.is_crit, rb.is_crit)
		assert_eq(ra.amount, rb.amount)


func test_armor_reduces_damage() -> void:
	var defender: CombatStats = CombatStats.new()
	defender.armor = 0.25
	assert_eq(CombatMath.damage(20.0, CombatStats.new(), defender, rng).amount, 15)


func test_armor_is_capped_at_60_percent() -> void:
	var defender: CombatStats = CombatStats.new()
	defender.armor = 0.95
	assert_eq(CombatMath.effective_armor(0.95), CombatMath.ARMOR_CAP)
	assert_eq(CombatMath.damage(100.0, CombatStats.new(), defender, rng).amount, 40)


func test_negative_armor_does_not_add_damage() -> void:
	assert_eq(CombatMath.effective_armor(-0.5), 0.0)


func test_damage_taken_multiplier_applies() -> void:
	var defender: CombatStats = CombatStats.new()
	defender.damage_taken_multiplier = 1.2
	assert_eq(CombatMath.damage(10.0, CombatStats.new(), defender, rng).amount, 12)


func test_landed_hit_deals_at_least_one() -> void:
	var defender: CombatStats = CombatStats.new()
	defender.armor = 0.6
	assert_eq(CombatMath.damage(1.0, CombatStats.new(), defender, rng).amount, 1)


func test_zero_base_deals_nothing() -> void:
	assert_eq(CombatMath.damage(0.0, CombatStats.new(), CombatStats.new(), rng).amount, 0)
