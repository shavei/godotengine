extends Ability
## Fire, Ember Bolt (docs/CONTENT.md Section 1): a fireball that burns what it hits.


func cast(hero: Hero, power: PowerData, level: int, aim: Vector2) -> void:
	fire_fan(hero, power, level, aim)
