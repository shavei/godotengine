extends Ability
## Stone, Bulwark (docs/CONTENT.md Section 1): a shield that soaks up damage, then bursts
## around the hero when it breaks or runs out, staggering what it hits.
## Level 3: the burst also throws spikes in a ring. Level 5: the shield reflects enemy
## projectiles.


func cast(hero: Hero, power: PowerData, level: int, _aim: Vector2) -> void:
	var shield: StoneShield = StoneShield.raise(hero, power, attack_for(hero, power, level))
	shield.reflects = PowerRules.has_upgrade(level, 5)
	if PowerRules.has_upgrade(level, 3) and power.level3_attack != null and power.level3_count > 0:
		_arm(shield, hero, power, PowerRules.scaled_attack(power.level3_attack, level, hero.balance))


## Static, so the connected lambda does not depend on this Ability (freed after the cast).
static func _arm(shield: StoneShield, hero: Hero, power: PowerData, spike: AttackData) -> void:
	shield.burst.connect(func(_at: Vector2) -> void:
		for i: int in power.level3_count:
			PowerProjectile.fire(hero, Vector2.RIGHT.rotated(TAU * i / power.level3_count), power, spike))
