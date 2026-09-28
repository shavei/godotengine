extends Ability
## Growth, Bramble (docs/CONTENT.md Section 1): a vine patch at the hero's feet that roots
## enemies in it and heals the hero while they stand inside.


func cast(hero: Hero, power: PowerData, level: int, _aim: Vector2) -> void:
	BramblePatch.grow(hero, power, attack_for(hero, power, level))
