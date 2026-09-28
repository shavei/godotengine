class_name PowerRules
extends RefCounted
## Power numbers (docs/GDD.md Sections 4.1 and 4.3): each level adds power damage, Focus
## adds power damage and shortens cooldowns. Numbers come from BalanceData.


## Damage multiplier from the power's level alone (level 1 = 1.0, +20% per level).
static func level_multiplier(level: int, balance: BalanceData) -> float:
	var capped: int = clampi(level, 1, maxi(balance.power_level_cap, 1))
	return 1.0 + balance.power_damage_per_level * (capped - 1)


## The power's hit at `level`: a copy of its attack with the damage scaled. Focus is not
## in here; it goes into the caster's power CombatStats (focus_damage_bonus).
static func attack_at_level(power: PowerData, level: int, balance: BalanceData) -> AttackData:
	var attack: AttackData = power.attack.duplicate() as AttackData
	attack.damage = power.attack.damage * level_multiplier(level, balance)
	return attack


## Additive power damage bonus from Focus points (0.03 per point = +3%).
static func focus_damage_bonus(focus: int, balance: BalanceData) -> float:
	return balance.focus_power_damage * maxi(focus, 0)


## Seconds between casts after Focus (-1.5% per point).
static func cooldown(power: PowerData, focus: int, balance: BalanceData) -> float:
	var cut: float = clampf(balance.focus_cooldown * maxi(focus, 0), 0.0, 0.9)
	return power.base_cooldown * (1.0 - cut)
