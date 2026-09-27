extends State
## Short stagger after taking a hit. Knockback does the moving.

var _time: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_time = 0.0


func physics_update(delta: float) -> void:
	var hero: Hero = actor
	_time += delta
	hero.velocity = hero.velocity.move_toward(Vector2.ZERO, hero.balance.hero_friction * delta)
	hero.apply_movement()
	if _time >= hero.balance.hurt_stun:
		machine.transition_to(&"Move")
