class_name ChargerAI
extends EnemyAI
## Charger (Tusk Boar): lines up, telegraphs a lane, then charges straight along it.
## Charging into a wall stuns it (bait it into walls). Hits do not interrupt a charger
## whose data has hit_stun 0.

enum Phase { STALK, WINDUP, CHARGE, STUNNED, RECOVER }

var phase: Phase = Phase.STALK
var _time: float = 0.0
var _direction: Vector2 = Vector2.RIGHT


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
				_direction = to_target.normalized()
				enemy.face(_direction)
				var lane: float = data.charge_speed * attack.active
				enemy.telegraph_line(_direction, lane, (data.body_radius + attack.radius), attack.windup)
				_set_phase(Phase.WINDUP)
			else:
				enemy.move_toward_direction(to_target.normalized(), delta)
		Phase.WINDUP:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= attack.windup:
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


func is_stunned() -> bool:
	return phase == Phase.STUNNED


func _set_phase(next: Phase) -> void:
	phase = next
	_time = 0.0
