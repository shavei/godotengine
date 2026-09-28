extends Ability
## Frost, Frost Shard (docs/CONTENT.md Section 1): a fan of shards that chill. Up close
## every shard hits the same enemy, which is enough stacks to freeze it.


func cast(hero: Hero, power: PowerData, level: int, aim: Vector2) -> void:
	fire_fan(hero, power, level, aim)
