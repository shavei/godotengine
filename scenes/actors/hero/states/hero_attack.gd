extends State
## One step of the weapon combo: wind-up, active (hitbox on), recovery.
## A press during the swing queues the next step; a dodge or a power can cancel the recovery.
## The move input steers the hero during the whole swing (Balance attack_move_scale).
## The hero keeps turning toward the aim during the swing; only the strike itself (hitbox
## and slash) stays where it was aimed, and the weapon follows the aim again once it fades.
## Steering keeps the hero's momentum (no snap on the first frame); the lunge is added on top.
## A press during the finisher is not used up: it stays buffered and starts the next combo.
## Hero.attack_speed (Fever) runs the swing's clock faster; movement keeps real time.

## Seconds the slash stays visible after the hitbox turns off.
const SLASH_LINGER: float = 0.08

var _attack: AttackData
var _step: int = 0
var _dir: Vector2 = Vector2.RIGHT
var _time: float = 0.0
var _queued: bool = false
var _hit_started: bool = false
## The hero's own movement during the swing, without the lunge.
var _move_velocity: Vector2 = Vector2.ZERO


func enter(_msg: Dictionary = {}) -> void:
	var hero: Hero = actor
	_step = hero.combo_step % hero.weapon.combo.size()
	_attack = hero.weapon.combo[_step]
	hero.facing = hero.attack_direction()
	_dir = hero.facing
	_time = 0.0
	_queued = false
	_hit_started = false
	# Keep the running momentum but drop any lunge left over from the previous swing.
	_move_velocity = hero.velocity.limit_length(hero.balance.hero_move_speed)
	hero.weapon_pivot.rotation = _dir.angle()
	hero.hitbox_shape.position = Vector2(_attack.reach, 0)
	(hero.hitbox_shape.shape as CircleShape2D).radius = _attack.radius


func exit() -> void:
	var hero: Hero = actor
	hero.hitbox.deactivate()


func physics_update(delta: float) -> void:
	var hero: Hero = actor
	_time += delta * hero.attack_speed
	hero.update_facing()
	var is_last: bool = _step >= hero.weapon.combo.size() - 1
	if not is_last and hero.consume(&"attack"):
		_queued = true
	var hit_end: float = _attack.windup + _attack.active
	var steer: Vector2 = hero.input.get_move() * hero.balance.hero_move_speed * hero.balance.attack_move_scale
	_move_velocity = Hero.steer(_move_velocity, steer, hero.balance, delta)

	if _time < _attack.windup:
		hero.velocity = _move_velocity + _dir * _attack.lunge_speed
	elif _time < hit_end:
		if not _hit_started:
			_hit_started = true
			hero.hitbox.activate(_attack)
			var big: bool = _step == hero.weapon.combo.size() - 1
			hero.swing.play(_attack.reach + _attack.radius * 0.4, 6.0 if big else 4.0, _attack.active + SLASH_LINGER)
		hero.velocity = _move_velocity + _dir * _attack.lunge_speed * 0.5
	else:
		hero.hitbox.deactivate()
		hero.velocity = _move_velocity
		if _time >= hit_end + SLASH_LINGER:
			hero.weapon_pivot.rotation = hero.facing.angle()
		# Dodge or a power cancels recovery.
		if hero.try_dodge() or hero.try_cast():
			_end_combo_early()
			return
		if _queued and not is_last and _time >= hit_end + hero.weapon.chain_after:
			hero.combo_step = _step + 1
			machine.transition_to(&"Attack")
			return
		if _time >= hit_end + _attack.recovery:
			hero.combo_step = (_step + 1) % hero.weapon.combo.size()
			hero.combo_timer = hero.balance.combo_reset
			machine.transition_to(&"Move")
			return
	hero.apply_movement()


func _end_combo_early() -> void:
	var hero: Hero = actor
	hero.combo_step = (_step + 1) % hero.weapon.combo.size()
	hero.combo_timer = hero.balance.combo_reset
