extends Ability
## Fire, Ember Bolt (docs/CONTENT.md Section 1): a fireball that burns what it hits.
## Level 3: it explodes on impact (an enemy or a wall). Level 5: the explosion leaves
## burning ground for a few seconds.


func cast(hero: Hero, power: PowerData, level: int, aim: Vector2) -> void:
	var shots: Array[PowerProjectile] = fire_fan(hero, power, level, aim)
	if PowerRules.has_upgrade(level, 3) and power.level3_attack != null:
		_arm(shots, hero, power, level)


## Static, so the connected lambdas do not depend on this Ability (freed after the cast).
static func _arm(shots: Array[PowerProjectile], hero: Hero, power: PowerData, level: int) -> void:
	var explode: Callable = func(at: Vector2) -> void:
		# Deferred: a wall hit arrives during a physics callback, where new areas cannot be added.
		(func() -> void: _explode(hero, power, level, at)).call_deferred()
	for shot: PowerProjectile in shots:
		shot.hit.connect(func(hurtbox: HurtboxComponent, _result: DamageResult) -> void: explode.call(hurtbox.global_position))
		shot.landed.connect(func(at: Vector2, hit_wall: bool) -> void:
			if hit_wall:
				explode.call(at))


static func _explode(hero: Hero, power: PowerData, level: int, at: Vector2) -> void:
	if not is_instance_valid(hero) or not hero.is_inside_tree():
		return
	var blast: AttackData = PowerRules.scaled_attack(power.level3_attack, level, hero.balance)
	PowerBurst.spawn(hero.get_parent(), at, blast, hero.power_stats, power.color)
	if PowerRules.has_upgrade(level, 5) and power.level5_attack != null:
		var ground: PowerPatch = PowerPatch.make(hero, power.color)
		ground.vines = false
		ground.radius = power.level5_radius
		ground.duration = power.level5_duration
		ground.pulse_attack = PowerRules.scaled_attack(power.level5_attack, level, hero.balance)
		ground.pulse_interval = power.level5_interval
		ground.place(at)
