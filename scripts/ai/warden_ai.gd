class_name WardenAI
extends BossAI
## Warden of Roots, phase 1 (docs/CONTENT.md Section 6.1): it never walks, its roots do.
## - Volley: shows a fan of lanes, then fires a seed down each one.
## - Roots: two root walls burst up on either side of the target, making a lane that
##   points at the Warden. The walls block seeds too, so they trap and shelter.
## - A target right next to it gets a root slam around its body instead.
## Phase 2 (vines that shrink the arena) comes with the full Mossy Hollow in M7.

enum Phase { IDLE, VOLLEY_WINDUP, SLAM_WINDUP, SLAM, RECOVER }

const VOLLEY: StringName = &"volley"
const ROOTS: StringName = &"roots"

var phase: Phase = Phase.IDLE

var _time: float = 0.0
var _directions: Array[Vector2] = []
var _recovery: float = 0.0


func setup(owner_enemy: Enemy) -> void:
	super.setup(owner_enemy)
	cooldown = boss.attack_cooldown


func tick(delta: float) -> void:
	var target: Node2D = enemy.find_target()
	_time += delta
	cooldown -= delta
	enemy.move_toward_direction(Vector2.ZERO, delta)
	match phase:
		Phase.IDLE:
			if target == null or cooldown > 0.0:
				if target != null:
					enemy.face(target.global_position - enemy.global_position)
				return
			_start_move(target)
		Phase.VOLLEY_WINDUP:
			if _time >= boss.attack.windup:
				for direction: Vector2 in _directions:
					enemy.fire_projectile(direction)
				_recover(boss.attack.recovery)
		Phase.SLAM_WINDUP:
			if _time >= boss.close_attack.windup:
				enemy.start_attack(boss.close_attack)
				_set_phase(Phase.SLAM)
		Phase.SLAM:
			if _time >= boss.close_attack.active:
				enemy.end_attack()
				_recover(boss.close_attack.recovery)
		Phase.RECOVER:
			if _time >= _recovery:
				cooldown = boss.attack_cooldown
				_set_phase(Phase.IDLE)


func _start_move(target: Node2D) -> void:
	var to_target: Vector2 = target.global_position - enemy.global_position
	enemy.face(to_target)
	if boss.close_attack != null and to_target.length() <= boss.close_range:
		enemy.face(Vector2.RIGHT)
		enemy.telegraph_attack_self(boss.close_attack.radius, boss.close_attack.windup)
		_set_phase(Phase.SLAM_WINDUP)
		return
	match next_move():
		VOLLEY:
			_directions = fan(to_target, boss.volley_count, boss.volley_spread_degrees)
			enemy.telegraph_lines(_directions, boss.projectile_range, boss.attack.radius * 2.0, boss.attack.windup)
			_set_phase(Phase.VOLLEY_WINDUP)
		ROOTS:
			var along: Vector2 = to_target.normalized() if to_target != Vector2.ZERO else Vector2.DOWN
			var side: Vector2 = along.orthogonal()
			for side_sign: float in [-1.0, 1.0]:
				enemy.raise_root_wall(target.global_position + side * side_sign * boss.root_wall_gap, along)
			_recover(boss.root_wall.windup)


## `count` directions spread evenly over `spread_degrees`, centered on `toward`.
static func fan(toward: Vector2, count: int, spread_degrees: float) -> Array[Vector2]:
	var center: Vector2 = toward.normalized() if toward != Vector2.ZERO else Vector2.DOWN
	var result: Array[Vector2] = []
	var spread: float = deg_to_rad(spread_degrees)
	for i: int in count:
		var offset: float = 0.0 if count <= 1 else -spread * 0.5 + spread * i / (count - 1)
		result.append(center.rotated(offset))
	return result


func _recover(seconds: float) -> void:
	_recovery = seconds
	_set_phase(Phase.RECOVER)


func _set_phase(next: Phase) -> void:
	phase = next
	_time = 0.0
