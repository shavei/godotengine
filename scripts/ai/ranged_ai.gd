class_name RangedAI
extends EnemyAI
## Ranged kiter (Thorn Archer): keeps its distance, telegraphs the shot lane, then fires
## a projectile along it. The aim locks when the telegraph starts, so a side step dodges.

enum Phase { POSITION, WINDUP, RECOVER }

var phase: Phase = Phase.POSITION
var _time: float = 0.0
var _direction: Vector2 = Vector2.RIGHT


func tick(delta: float) -> void:
	var data: EnemyData = enemy.data
	var attack: AttackData = data.attack
	var target: Node2D = enemy.find_target()
	_time += delta
	cooldown -= delta
	match phase:
		Phase.POSITION:
			if target == null:
				enemy.move_toward_direction(Vector2.ZERO, delta)
				return
			var to_target: Vector2 = target.global_position - enemy.global_position
			var distance: float = to_target.length()
			var sees: bool = enemy.can_see(target)
			enemy.face(to_target)
			if cooldown <= 0.0 and sees and distance <= data.attack_range:
				_direction = to_target.normalized()
				enemy.telegraph_line(_direction, minf(distance + 24.0, data.projectile_range), 3.0, attack.windup)
				_set_phase(Phase.WINDUP)
			elif distance < data.keep_distance * 0.8:
				enemy.move_toward_direction(-to_target.normalized(), delta)
			elif distance > data.keep_distance * 1.2 or not sees:
				enemy.move_toward_direction(to_target.normalized(), delta)
			else:
				enemy.move_toward_direction(Vector2.ZERO, delta)
		Phase.WINDUP:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= attack.windup:
				enemy.fire_projectile(_direction)
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= attack.recovery:
				cooldown = data.attack_cooldown
				_set_phase(Phase.POSITION)


func interrupt() -> void:
	super.interrupt()
	_set_phase(Phase.RECOVER)


func _set_phase(next: Phase) -> void:
	phase = next
	_time = 0.0
