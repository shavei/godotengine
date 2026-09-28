class_name WaveDirector
extends Node2D
## Runs an EncounterData in a room: warns where each enemy will appear, spawns the
## wave, and reports wave and room clears. The rules live in WaveTracker.

signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal room_cleared
## An enemy of the encounter appeared (not split or summoned children).
signal enemy_spawned(enemy: Enemy)
## Every tracked enemy death, before any clear it causes (the room drops loot here).
signal enemy_died(enemy: Enemy)

@export var encounter: EncounterData
## Where enemies may appear, in this node's local space. Place them clear of pillars.
@export var spawn_points: Array[Vector2] = []
## Enemies are added here (the room's y-sorted actor layer).
@export var actors: Node2D
## Spawn points closer than this to a hero are used last (px).
@export var min_hero_distance: float = 100.0
## How long the spawn marker shows before the enemy appears (s).
@export var spawn_warning: float = 0.7
## 0 picks a random seed.
@export var rng_seed: int = 0
@export var autostart: bool = true

var tracker: WaveTracker
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Spawns waiting on their warning: { "data", "position", "time", "marker" }.
var _pending: Array[Dictionary] = []
## Counts down to the next wave after a clear; negative when idle.
var _next_wave_in: float = -1.0


func _ready() -> void:
	if rng_seed != 0:
		rng.seed = rng_seed
	else:
		rng.randomize()
	if autostart:
		start()


func start() -> void:
	var count: int = encounter.waves.size() if encounter != null else 0
	tracker = WaveTracker.new(count)
	if count == 0:
		room_cleared.emit()
		EventBus.room_cleared.emit()
		return
	_start_next_wave()


## Stops the encounter: no more waves or spawns (the debug console's skip_room).
func stop() -> void:
	_next_wave_in = -1.0
	for entry: Dictionary in _pending:
		(entry["marker"] as Node).queue_free()
	_pending.clear()


func is_room_cleared() -> bool:
	return tracker != null and tracker.is_room_cleared()


func _physics_process(delta: float) -> void:
	if _next_wave_in >= 0.0:
		_next_wave_in -= delta
		if _next_wave_in < 0.0:
			_start_next_wave()
	for i: int in range(_pending.size() - 1, -1, -1):
		var entry: Dictionary = _pending[i]
		entry["time"] -= delta
		if entry["time"] <= 0.0:
			_pending.remove_at(i)
			(entry["marker"] as Node).queue_free()
			_spawn(entry["data"], entry["position"])


func _start_next_wave() -> void:
	var index: int = tracker.start_next_wave()
	if index < 0:
		return
	var wave: WaveData = encounter.waves[index]
	var points: Array[Vector2] = _pick_points(wave.enemies.size())
	for i: int in wave.enemies.size():
		var marker: TelegraphRing = TelegraphRing.new()
		marker.color = Color(0.75, 0.55, 1.0)
		marker.position = points[i]
		add_child(marker)
		marker.play(wave.enemies[i].body_radius + 6.0, spawn_warning)
		_pending.append({"data": wave.enemies[i], "position": points[i], "time": spawn_warning, "marker": marker})
	tracker.add_alive(wave.enemies.size())
	wave_started.emit(index, tracker.wave_count)


func _spawn(data: EnemyData, local_position: Vector2) -> void:
	var enemy: Enemy = Enemy.create(data)
	var parent: Node2D = actors if actors != null else self
	parent.add_child(enemy)
	enemy.global_position = to_global(local_position)
	enemy.reset_physics_interpolation()
	_track(enemy)
	enemy_spawned.emit(enemy)


func _track(enemy: Enemy) -> void:
	enemy.spawned.connect(_on_enemy_spawned)
	enemy.died.connect(_on_enemy_died)


func _on_enemy_spawned(child: Enemy) -> void:
	tracker.add_alive()
	_track(child)


func _on_enemy_died(enemy: Enemy) -> void:
	enemy_died.emit(enemy)
	match tracker.remove_alive():
		WaveTracker.Event.WAVE_CLEARED:
			wave_cleared.emit(tracker.current_wave)
			_next_wave_in = encounter.wave_delay
		WaveTracker.Event.ROOM_CLEARED:
			wave_cleared.emit(tracker.current_wave)
			room_cleared.emit()
			EventBus.room_cleared.emit()


## Shuffled spawn points, the ones far from every hero first. Repeats if there are
## more enemies than points.
func _pick_points(count: int) -> Array[Vector2]:
	var far: Array[Vector2] = []
	var near: Array[Vector2] = []
	for point: Vector2 in spawn_points:
		if _distance_to_nearest_hero(to_global(point)) >= min_hero_distance:
			far.append(point)
		else:
			near.append(point)
	_shuffle(far)
	_shuffle(near)
	var ordered: Array[Vector2] = far + near
	if ordered.is_empty():
		ordered.append(Vector2.ZERO)
	var result: Array[Vector2] = []
	for i: int in count:
		# A small jitter keeps repeated points from stacking enemies exactly.
		var jitter: Vector2 = Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0)) if i >= ordered.size() else Vector2.ZERO
		result.append(ordered[i % ordered.size()] + jitter)
	return result


func _distance_to_nearest_hero(point: Vector2) -> float:
	var best: float = INF
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
		var hero: Node2D = node as Node2D
		if hero != null:
			best = minf(best, point.distance_to(hero.global_position))
	return best


func _shuffle(points: Array[Vector2]) -> void:
	for i: int in range(points.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Vector2 = points[i]
		points[i] = points[j]
		points[j] = swap
