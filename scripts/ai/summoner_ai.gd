class_name SummonerAI
extends EnemyAI
## Summoner (Spore Witch): keeps its distance, lobs clouds at the target's feet and
## calls minions. The cloud's spot is marked for the whole windup, so moving dodges it.
## Summons wait for `summon_cooldown` and stop while `summon_max_alive` are alive.

enum Phase { POSITION, CAST, SUMMON, RECOVER }

var phase: Phase = Phase.POSITION
var summon_timer: float = 0.0
## Minions this summoner called (dead ones are pruned when counted).
var minions: Array[Enemy] = []

var _time: float = 0.0
var _cast_at: Vector2 = Vector2.ZERO


func setup(owner_enemy: Enemy) -> void:
	super.setup(owner_enemy)
	# The first call comes a little sooner than the rest.
	summon_timer = owner_enemy.data.summon_cooldown * 0.5


func tick(delta: float) -> void:
	var data: EnemyData = enemy.data
	var attack: AttackData = data.attack
	var target: Node2D = enemy.find_target()
	_time += delta
	cooldown -= delta
	summon_timer -= delta
	match phase:
		Phase.POSITION:
			if target == null:
				enemy.move_toward_direction(Vector2.ZERO, delta)
				return
			var to_target: Vector2 = target.global_position - enemy.global_position
			var distance: float = to_target.length()
			var sees: bool = enemy.can_see(target)
			enemy.face(to_target)
			if can_summon():
				enemy.telegraph_attack_self(data.body_radius + 12.0, data.summon_windup)
				_set_phase(Phase.SUMMON)
			elif cooldown <= 0.0 and sees and distance <= data.attack_range and data.hazard != null:
				_cast_at = target.global_position
				enemy.telegraph_at(_cast_at, data.hazard.radius, attack.windup)
				_set_phase(Phase.CAST)
			elif distance < data.keep_distance * 0.8:
				enemy.move_toward_direction(-to_target.normalized(), delta)
			elif distance > data.keep_distance * 1.2 or not sees:
				enemy.move_toward_direction(to_target.normalized(), delta)
			else:
				enemy.move_toward_direction(Vector2.ZERO, delta)
		Phase.CAST:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= attack.windup:
				enemy.drop_hazard(_cast_at)
				_set_phase(Phase.RECOVER)
		Phase.SUMMON:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= data.summon_windup:
				var count: int = mini(data.summon_count, data.summon_max_alive - alive_minions())
				minions.append_array(enemy.summon_minions(data.summon, count))
				summon_timer = data.summon_cooldown
				_set_phase(Phase.RECOVER)
		Phase.RECOVER:
			enemy.move_toward_direction(Vector2.ZERO, delta)
			if _time >= attack.recovery:
				cooldown = data.attack_cooldown
				_set_phase(Phase.POSITION)


func can_summon() -> bool:
	var data: EnemyData = enemy.data
	return data.summon != null and summon_timer <= 0.0 and alive_minions() < data.summon_max_alive


func alive_minions() -> int:
	for i: int in range(minions.size() - 1, -1, -1):
		if not is_instance_valid(minions[i]) or minions[i].is_dead():
			minions.remove_at(i)
	return minions.size()


func interrupt() -> void:
	super.interrupt()
	_set_phase(Phase.RECOVER)


func _set_phase(next: Phase) -> void:
	phase = next
	_time = 0.0
