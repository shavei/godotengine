extends Ability
## Growth, Bramble (docs/CONTENT.md Section 1): a vine patch at the hero's feet that roots
## enemies in it and heals the hero while they stand inside.
## Level 3: a bigger patch that lasts longer. Level 5: the roots deal damage and the patch
## spreads as it lasts.


func cast(hero: Hero, power: PowerData, level: int, _aim: Vector2) -> void:
	var patch: PowerPatch = PowerPatch.make(hero, power.color)
	patch.radius = power.area_radius
	patch.duration = power.area_duration
	if PowerRules.has_upgrade(level, 3):
		patch.radius *= power.level3_area_scale
		patch.duration *= power.level3_duration_scale
	patch.pulse_attack = attack_for(hero, power, level)
	patch.pulse_interval = power.area_interval
	patch.heal_per_second = power.heal_per_second
	if PowerRules.has_upgrade(level, 5) and power.level5_attack != null:
		patch.damage_attack = PowerRules.scaled_attack(power.level5_attack, level, hero.balance)
		patch.damage_interval = power.level5_interval
		patch.spread = power.level5_spread
	patch.place(hero.global_position)
