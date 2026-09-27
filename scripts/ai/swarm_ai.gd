class_name SwarmAI
extends EnemyAI
## Swarm (Sproutling, seedling): walks straight at the target and bites when close.
## Weak alone; dangerous in numbers.

enum Phase { CHASE, WINDUP, BITE, RECOVER }

var phase: Phase = Phase.CHASE
var _time: float = 0.0


func tick(delta: float) -> void:
	var data: EnemyData = enemy.data
	var attack: AttackData = data.attack
	var target: Node2D = enemy.find_target()
	_time += delta
	cooldown -= delta
	match phase:
		Phase.CHASE:
			if target == null:
				enemy.move_toward_direction(Vector2.ZERO, delta)
				return
			var to_target: Vector2 = target.global_position - enemy.global_position
			if to_target.length() <= data.attack_range and cooldown <= 0.0:
				enemy.face(to_target)
				enemy.telegraph_attack(attack)
				_set_phase(Phase.WINDUP)
			else:
				enemy.move_toward_direction(to_target.normalized(), delta)
		Phase.WINDUP:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= attack.windup:
				enemy.start_attack(attack)
				_set_phase(Phase.BITE)
		Phase.BITE:
			enemy.velocity = enemy.facing * attack.lunge_speed
			enemy.apply_movement()
			if _time >= attack.active:
				enemy.end_attack()
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= attack.recovery:
				cooldown = data.attack_cooldown
				_set_phase(Phase.CHASE)


func interrupt() -> void:
	super.interrupt()
	_set_phase(Phase.RECOVER)


func _set_phase(next: Phase) -> void:
	phase = next
	_time = 0.0
