class_name MotherToadAI
extends BossAI
## Mother Toad (docs/CONTENT.md Section 6.1): tongue grabs and belly flops.
## - Tongue: shows a lane, then shoots out along it. A hit pulls the target in.
## - Flop: marks the target's spot, leaps (can't be hit in the air), lands with a big
##   area hit, then sits still for a while: the time to punish her.
## Enraged (below half HP) she flops twice in a row.

enum Phase { IDLE, TONGUE_WINDUP, TONGUE_OUT, TONGUE_BACK, LEAP_WINDUP, AIRBORNE, LANDED, RECOVER }

const TONGUE: StringName = &"tongue"
const FLOP: StringName = &"flop"

var phase: Phase = Phase.IDLE
## The move chosen when the cooldown ended, played once in reach.
var move: StringName = &""

var _time: float = 0.0
var _direction: Vector2 = Vector2.DOWN
var _tongue_length: float = 0.0
var _leap_from: Vector2 = Vector2.ZERO
var _leap_to: Vector2 = Vector2.ZERO


func setup(owner_enemy: Enemy) -> void:
	super.setup(owner_enemy)
	enemy.hitbox.hit_landed.connect(_on_hit_landed)
	cooldown = boss.attack_cooldown


func tick(delta: float) -> void:
	var target: Node2D = enemy.find_target()
	_time += delta
	cooldown -= delta
	match phase:
		Phase.IDLE:
			_idle(target, delta)
		Phase.TONGUE_WINDUP:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= boss.tongue.windup:
				enemy.start_attack(boss.tongue)
				_set_phase(Phase.TONGUE_OUT)
		Phase.TONGUE_OUT:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			_tongue_length = boss.tongue_range * minf(_time / maxf(boss.tongue.active, 0.01), 1.0)
			enemy.lash(_tongue_length)
			if _time >= boss.tongue.active:
				enemy.end_attack()
				_set_phase(Phase.TONGUE_BACK)
		Phase.TONGUE_BACK:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			var back: float = 1.0 - minf(_time / maxf(boss.tongue.recovery, 0.01), 1.0)
			enemy.lash(_tongue_length * back)
			if _time >= boss.tongue.recovery:
				enemy.lash(0.0)
				cooldown = boss.tongue_cooldown
				_set_phase(Phase.IDLE)
		Phase.LEAP_WINDUP:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			# Squat before the jump.
			var squat: float = minf(_time / boss.attack.windup, 1.0)
			enemy.visual.scale = Vector2(1.0 + 0.25 * squat, 1.0 - 0.25 * squat)
			if _time >= boss.attack.windup:
				_leap_from = enemy.global_position
				enemy.visual.scale = Vector2.ONE
				enemy.set_airborne(true)
				_set_phase(Phase.AIRBORNE)
		Phase.AIRBORNE:
			var t: float = minf(_time / maxf(boss.leap_time, 0.01), 1.0)
			enemy.global_position = _leap_from.lerp(_leap_to, t)
			enemy.visual.position.y = -sin(t * PI) * boss.leap_height
			if t >= 1.0:
				enemy.visual.position.y = 0.0
				enemy.set_airborne(false)
				enemy.clear_markers()
				enemy.velocity = Vector2.ZERO
				enemy.start_attack(boss.attack)
				_set_phase(Phase.LANDED)
		Phase.LANDED:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= boss.attack.active:
				enemy.end_attack()
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= boss.attack.recovery:
				cooldown = boss.attack_cooldown
				_set_phase(Phase.IDLE)


func _idle(target: Node2D, delta: float) -> void:
	if target == null:
		enemy.move_toward_direction(Vector2.ZERO, delta)
		return
	var to_target: Vector2 = target.global_position - enemy.global_position
	enemy.face(to_target)
	if cooldown > 0.0:
		enemy.move_toward_direction(Vector2.ZERO, delta)
		return
	if move == &"":
		move = next_move()
	match move:
		TONGUE:
			if to_target.length() > boss.tongue_range * 0.9:
				enemy.move_toward_direction(to_target.normalized(), delta)
				return
			_direction = to_target.normalized()
			enemy.face(_direction)
			enemy.telegraph_line(_direction, boss.tongue_range, boss.tongue.radius * 2.0, boss.tongue.windup)
			_set_phase(Phase.TONGUE_WINDUP)
		FLOP:
			_leap_to = target.global_position
			enemy.telegraph_at(_leap_to, boss.attack.radius, boss.attack.windup + boss.leap_time, TelegraphRing.DANGER_COLOR)
			_set_phase(Phase.LEAP_WINDUP)
		_:
			enemy.move_toward_direction(Vector2.ZERO, delta)
	move = &""


## A tongue hit pulls the target in and the tongue snaps back.
func _on_hit_landed(hurtbox: HurtboxComponent, _result: DamageResult) -> void:
	if phase != Phase.TONGUE_OUT:
		return
	var body: Node2D = hurtbox.get_parent() as Node2D
	var pushable: KnockbackComponent = body.get(&"knockback") as KnockbackComponent if body != null else null
	if pushable != null:
		pushable.apply((enemy.global_position - body.global_position).normalized() * boss.tongue_pull)
	enemy.end_attack()
	_tongue_length = enemy.global_position.distance_to(body.global_position) if body != null else _tongue_length
	_set_phase(Phase.TONGUE_BACK)


func is_airborne() -> bool:
	return phase == Phase.AIRBORNE


## A stun can't pull her out of the air; it waits until she lands.
func can_be_held() -> bool:
	return phase != Phase.AIRBORNE


## Stunned: drop the move, stand up straight, and start over after the usual pause.
func interrupt() -> void:
	super.interrupt()
	enemy.visual.scale = Vector2.ONE
	move = &""
	cooldown = boss.attack_cooldown
	_set_phase(Phase.IDLE)


func _set_phase(next: Phase) -> void:
	phase = next
	_time = 0.0
