extends Ability
## Stone, Bulwark (docs/CONTENT.md Section 1): a shield that soaks up damage, then bursts
## around the hero when it breaks or runs out, staggering what it hits.


func cast(hero: Hero, power: PowerData, level: int, _aim: Vector2) -> void:
	StoneShield.raise(hero, power, attack_for(hero, power, level))
