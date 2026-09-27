class_name ChargerAI
extends EnemyAI
## Charger (Tusk Boar): lines up, telegraphs a lane, then charges straight along it.
## Charging into a wall stuns it (bait it into walls). Hits do not interrupt a charger
## whose data has hit_stun 0. With `charge_chain` above 1 (Elder Boar) it re-aims and
## charges again after a shorter telegraph; a wall stun ends the chain.

enum Phase { STALK, WINDUP, CHARGE, STUNNED, RECOVER }

var phase: Phase = Phase.STALK
var _time: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
## Telegraph time of the charge being wound up.
var _windup: float = 0.0
## Charges still to come in this chain.
var _chain_left: int = 0


func tick(delta: float) -> void:
	var data: EnemyData = enemy.data
	var attack: AttackData = data.attack
	var target: Node2D = enemy.find_target()
	_time += delta
	cooldown -= delta
	match phase:
		Phase.STALK:
			if target == null:
				enemy.move_toward_direction(Vector2.ZERO, delta)
				return
			var to_target: Vector2 = target.global_position - enemy.global_position
			if to_target.length() <= data.attack_range and cooldown <= 0.0 and enemy.can_see(target):
				_chain_left = maxi(data.charge_chain, 1) - 1
				_wind_up(to_target, attack.windup)
			else:
				enemy.move_toward_direction(to_target.normalized(), delta)
		Phase.WINDUP:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= _windup:
				enemy.start_attack(attack)
				_set_phase(Phase.CHARGE)
		Phase.CHARGE:
			enemy.velocity = _direction * data.charge_speed
			enemy.apply_movement()
			if enemy.hit_wall():
				enemy.end_attack()
				enemy.stun_feedback()
				_set_phase(Phase.STUNNED)
			elif _time >= attack.active:
				enemy.end_attack()
				if _chain_left > 0 and target != null:
					_chain_left -= 1
					_wind_up(target.global_position - enemy.global_position, data.chain_windup)
				else:
					_set_phase(Phase.RECOVER)
		Phase.STUNNED:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			enemy.visual.rotation = enemy.facing.angle() + sin(_time * 30.0) * 0.3
			if _time >= data.wall_stun:
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= attack.recovery:
				cooldown = data.attack_cooldown
				_set_phase(Phase.STALK)


func interrupt() -> void:
	super.interrupt()
	if phase != Phase.STUNNED:
		_set_phase(Phase.RECOVER)


## Aims along `toward`, shows the charge lane for `windup` seconds, then charges.
func _wind_up(toward: Vector2, windup: float) -> void:
	var data: EnemyData = enemy.data
	_direction = toward.normalized() if toward != Vector2.ZERO else enemy.facing
	_windup = windup
	enemy.face(_direction)
	var lane: float = data.charge_speed * data.attack.active
	enemy.telegraph_line(_direction, lane, data.body_radius + data.attack.radius, windup)
	_set_phase(Phase.WINDUP)


func is_stunned() -> bool:
	return phase == Phase.STUNNED


func _set_phase(next: Phase) -> void:
	phase = next
	_time = 0.0
