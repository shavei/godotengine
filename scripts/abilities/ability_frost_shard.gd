extends Ability
## Frost, Frost Shard (docs/CONTENT.md Section 1): a fan of shards that chill. Up close
## every shard hits the same enemy, which is enough stacks to freeze it.
## Level 3: shards pierce. Level 5: a shard that hits a frozen enemy shatters the ice for
## area damage around it (once per enemy per cast; the enemy stays frozen).


func cast(hero: Hero, power: PowerData, level: int, aim: Vector2) -> void:
	var shots: Array[PowerProjectile] = fire_fan(hero, power, level, aim)
	for shot: PowerProjectile in shots:
		shot.pierce = PowerRules.has_upgrade(level, 3)
	if PowerRules.has_upgrade(level, 5) and power.level5_attack != null:
		_arm(shots, hero, power, level)


## Static, so the connected lambdas do not depend on this Ability (freed after the cast).
static func _arm(shots: Array[PowerProjectile], hero: Hero, power: PowerData, level: int) -> void:
	var shattered: Array[HurtboxComponent] = []
	for shot: PowerProjectile in shots:
		shot.hit.connect(func(hurtbox: HurtboxComponent, _result: DamageResult) -> void:
			if hurtbox.status == null or not hurtbox.status.has(StatusEffects.FREEZE) or shattered.has(hurtbox):
				return
			shattered.append(hurtbox)
			var at: Vector2 = hurtbox.global_position
			(func() -> void: _shatter(hero, power, level, at)).call_deferred())


static func _shatter(hero: Hero, power: PowerData, level: int, at: Vector2) -> void:
	if not is_instance_valid(hero) or not hero.is_inside_tree():
		return
	var blast: AttackData = PowerRules.scaled_attack(power.level5_attack, level, hero.balance)
	PowerBurst.spawn(hero.get_parent(), at, blast, hero.power_stats, power.color.lightened(0.4))
