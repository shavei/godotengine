extends State
## Casting a power: a short wind-up (slowed, still aiming), then the ability goes off
## and its cooldown starts. A dodge cancels the cast (no cooldown spent); so does a hit.

var _slot: int = 0
var _time: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	var hero: Hero = actor
	_slot = msg.get("slot", 0)
	_time = 0.0
	hero.facing = hero.power_direction(_power(hero))


func physics_update(delta: float) -> void:
	var hero: Hero = actor
	_time += delta
	if hero.try_dodge():
		return
	hero.update_facing()
	hero.move_with_input(delta, hero.balance.power_cast_move_scale)
	if _time < hero.balance.power_cast_time:
		return
	hero.facing = hero.power_direction(_power(hero))
	hero.cast_power(_slot)
	machine.transition_to(&"Move")


func _power(hero: Hero) -> PowerData:
	var entry: PowerLoadout.Slot = hero.powers.slot(_slot)
	return entry.power if entry != null else null
