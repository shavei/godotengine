extends State
## Quick roll with invincibility frames. Stamina is paid by Hero.try_start_action().
## The hero rolls through enemy bodies (walls still block).

var _dir: Vector2 = Vector2.RIGHT
var _time: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	var hero: Hero = actor
	var move: Vector2 = hero.input.get_move()
	_dir = move.normalized() if move != Vector2.ZERO else hero.facing
	_time = 0.0
	hero.knockback.clear()
	hero.grant_iframes(hero.balance.dodge_iframes)
	hero.set_collision_mask_value(Hero.ENEMY_BODY_LAYER, false)


func exit() -> void:
	var hero: Hero = actor
	hero.set_collision_mask_value(Hero.ENEMY_BODY_LAYER, true)


func physics_update(delta: float) -> void:
	var hero: Hero = actor
	_time += delta
	var speed: float = hero.balance.dodge_distance / hero.balance.dodge_duration
	hero.velocity = _dir * speed
	hero.apply_movement()
	if _time >= hero.balance.dodge_duration:
		# Leave the roll at run speed so it flows into movement.
		hero.velocity = _dir * hero.balance.hero_move_speed
		machine.transition_to(&"Move")
