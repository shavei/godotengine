extends State
## Drinking a flask: slowed for a moment, then the heal lands.
## Getting hit cancels the drink and keeps the charge.

var _time: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_time = 0.0


func physics_update(delta: float) -> void:
	var hero: Hero = actor
	_time += delta
	hero.update_facing()
	hero.move_with_input(delta, hero.balance.flask_move_scale)
	if _time < hero.balance.flask_drink_time:
		return
	var amount: int = hero.flasks.drink(hero.health.hp, hero.health.max_hp)
	var healed: int = hero.health.heal(amount)
	if healed > 0:
		DamageNumber.spawn(hero.get_parent(), hero.global_position, "+%d" % healed, DamageNumber.COLOR_HEAL)
	machine.transition_to(&"Move")
