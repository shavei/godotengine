class_name CombatMath
extends RefCounted
## Damage formula from docs/GDD.md Section 7.2:
## final = base * weapon_tier * (1 + bonuses) * crit * status_mods * (1 - armor)
## Deterministic for a given RandomNumberGenerator state.

const ARMOR_CAP: float = 0.6


static func damage(base: float, attacker: CombatStats, defender: CombatStats,
		rng: RandomNumberGenerator, force_crit: bool = false) -> DamageResult:
	var result: DamageResult = DamageResult.new()
	if base <= 0.0:
		return result
	result.is_crit = force_crit or roll_crit(attacker.crit_chance, rng)
	var value: float = base * attacker.weapon_tier * (1.0 + attacker.damage_bonus)
	if result.is_crit:
		value *= attacker.crit_multiplier
	value *= defender.damage_taken_multiplier
	value *= 1.0 - effective_armor(defender.armor)
	# A landed hit always does at least 1 damage.
	result.amount = maxi(1, roundi(value))
	return result


static func roll_crit(chance: float, rng: RandomNumberGenerator) -> bool:
	if chance <= 0.0:
		return false
	return rng.randf() < chance


static func effective_armor(armor: float) -> float:
	return clampf(armor, 0.0, ARMOR_CAP)
