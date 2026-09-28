class_name PowerRules
extends RefCounted
## Power numbers (docs/GDD.md Sections 4.1 and 4.3): each level adds power damage, Focus
## adds power damage and shortens cooldowns, levels 3 and 5 add an upgrade, and each level
## costs Power Shards. Numbers come from BalanceData.

## Levels that add an upgrade effect (docs/CONTENT.md Section 1).
const UPGRADE_LEVELS: Array[int] = [3, 5]


## Damage multiplier from the power's level alone (level 1 = 1.0, +20% per level).
static func level_multiplier(level: int, balance: BalanceData) -> float:
	var capped: int = clampi(level, 1, maxi(balance.power_level_cap, 1))
	return 1.0 + balance.power_damage_per_level * (capped - 1)


## The power's hit at `level`: a copy of its attack with the damage scaled. Focus is not
## in here; it goes into the caster's power CombatStats (focus_damage_bonus).
static func attack_at_level(power: PowerData, level: int, balance: BalanceData) -> AttackData:
	return scaled_attack(power.attack, level, balance)


## A copy of any power hit (an upgrade's explosion, spikes, shatter) scaled to `level`.
## Null in, null out.
static func scaled_attack(attack: AttackData, level: int, balance: BalanceData) -> AttackData:
	if attack == null:
		return null
	var copy: AttackData = attack.duplicate() as AttackData
	copy.damage = attack.damage * level_multiplier(level, balance)
	return copy


## True once `level` has the upgrade that starts at `upgrade_level` (3 or 5).
static func has_upgrade(level: int, upgrade_level: int) -> bool:
	return level >= upgrade_level


## Power Shards to go from `level` to the next one; 0 at the cap.
static func level_up_cost(level: int, balance: BalanceData) -> int:
	if level < 1 or level >= balance.power_level_cap:
		return 0
	var index: int = level - 1
	return balance.power_level_costs[index] if index < balance.power_level_costs.size() else 0


## Power Shards to raise a power from level 1 to `level` (sum of the steps).
static func total_cost(level: int, balance: BalanceData) -> int:
	var total: int = 0
	for step: int in range(1, mini(level, balance.power_level_cap)):
		total += level_up_cost(step, balance)
	return total


## Additive power damage bonus from Focus points (0.03 per point = +3%).
static func focus_damage_bonus(focus: int, balance: BalanceData) -> float:
	return balance.focus_power_damage * maxi(focus, 0)


## Seconds between casts after Focus (-1.5% per point).
static func cooldown(power: PowerData, focus: int, balance: BalanceData) -> float:
	var cut: float = clampf(balance.focus_cooldown * maxi(focus, 0), 0.0, 0.9)
	return power.base_cooldown * (1.0 - cut)
