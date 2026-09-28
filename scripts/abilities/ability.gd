class_name Ability
extends RefCounted
## What a power does when cast (docs/ARCHITECTURE.md Section 7). PowerData.ability_script
## names the subclass; the hero makes one per cast and calls cast(). Abilities read every
## number from the PowerData and scale damage with PowerRules, so tuning is data only.


## Casts `power` at `level` from `hero` toward `aim` (a unit vector).
func cast(_hero: Hero, _power: PowerData, _level: int, _aim: Vector2) -> void:
	pass


## The power's hit at this level, for hitboxes the ability spawns.
func attack_for(hero: Hero, power: PowerData, level: int) -> AttackData:
	return PowerRules.attack_at_level(power, level, hero.balance)


## Fires the power's projectiles in a fan centered on `aim`.
func fire_fan(hero: Hero, power: PowerData, level: int, aim: Vector2) -> Array[PowerProjectile]:
	var shots: Array[PowerProjectile] = []
	var attack: AttackData = attack_for(hero, power, level)
	var count: int = maxi(power.projectile_count, 1)
	for i: int in count:
		var offset: float = 0.0
		if count > 1:
			offset = deg_to_rad(power.spread_degrees) * (float(i) / (count - 1) - 0.5)
		var direction: Vector2 = aim.rotated(offset)
		shots.append(PowerProjectile.fire(hero, direction, power, attack))
	return shots
