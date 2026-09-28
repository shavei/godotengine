class_name Enemy
extends CharacterBody2D
## Every enemy (docs/ARCHITECTURE.md Section 7): this scene plus an EnemyData resource.
## The data's ai_script decides behavior; this script gives the AI its verbs (move,
## face, telegraph, attack, shoot) and handles getting hit, statuses, splitting and dying.
## Statuses (StatusComponent): chill slows the AI's clock and movement, root stops
## movement, and freeze or a full stagger bar holds the AI (interrupting its move).

signal telegraph_started
## A new enemy appeared from this one (a Sproutling's seedlings). Emitted before died.
signal spawned(child: Enemy)
signal died(enemy: Enemy)
## A boss dropped below its enrage line (BossData.enrage_below).
signal enraged

const GROUP: StringName = &"enemies"
const SCENE_PATH: String = "res://scenes/actors/enemy/enemy.tscn"
const ARROW_SCENE: PackedScene = preload("res://scenes/actors/enemy/thorn_arrow.tscn")
const PATCH_SCENE: PackedScene = preload("res://scenes/actors/enemy/thorn_patch.tscn")
const ROOT_WALL_SCENE: PackedScene = preload("res://scenes/actors/enemy/root_wall.tscn")
const TONGUE_COLOR: Color = Color(0.95, 0.45, 0.55)
const ELITE_OUTLINE: Color = Color(1.0, 0.82, 0.3)
const WORLD_LAYER: int = 1
## px/s per second when speeding up or slowing down.
const ACCELERATION: float = 700.0
const DEATH_TIME: float = 0.35
## Distance split children pop out to.
const SPLIT_SPREAD: float = 10.0
## Distance summoned minions appear at.
const SUMMON_SPREAD: float = 22.0
const BURN_COLOR: Color = Color(1.0, 0.6, 0.25)

@export var data: EnemyData

var ai: EnemyAI
var stats: CombatStats = CombatStats.new()
## Direction the enemy faces and attacks (unit vector).
var facing: Vector2 = Vector2.DOWN

var _stun_time: float = 0.0
var _dead: bool = false
## True while frozen or stunned by a status (the AI was interrupted once on entry).
var _held: bool = false
## Warnings besides the body telegraph: a spot on the floor (a Spore Witch's cloud, a
## toad's landing) or a fan of lanes (a Warden's volley).
var _markers: Array[TelegraphRing] = []
## Drawn from the body to the hitbox for reaching attacks (Mother Toad's tongue).
var _lash_line: Line2D = null

@onready var body_shape: CollisionShape2D = $Shape
@onready var visual: PlaceholderShape = $Visual
@onready var telegraph: TelegraphRing = $Telegraph
@onready var attack_pivot: Node2D = $AttackPivot
@onready var hitbox: HitboxComponent = $AttackPivot/Hitbox
@onready var hitbox_shape: CollisionShape2D = $AttackPivot/Hitbox/Shape
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/Shape
@onready var health: HealthComponent = $Health
@onready var knockback: KnockbackComponent = $Knockback
@onready var status: StatusComponent = $Status


## Makes an enemy of the given type. Add it to the room's actor layer yourself.
static func create(enemy_data: EnemyData) -> Enemy:
	var packed: PackedScene = load(SCENE_PATH)
	var enemy: Enemy = packed.instantiate()
	enemy.data = enemy_data
	return enemy


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(AimAssist.GROUP)
	if data == null:
		push_error("Enemy %s has no EnemyData" % name)
		return
	# Shapes are made here so each enemy can have its own size.
	body_shape.shape = _circle(data.body_radius)
	hurtbox_shape.shape = _circle(data.body_radius + 2.0)
	hitbox_shape.shape = _circle(data.attack.radius if data.attack != null else 8.0)
	visual.size = Vector2.ONE * data.body_radius * 2.0
	visual.color = data.color
	if data.is_elite:
		visual.outline_color = ELITE_OUTLINE
	health.set_max_hp(data.max_hp, true)
	knockback.weight_scale = data.weight_scale
	stats.armor = data.armor
	hitbox.stats = stats
	hurtbox.stats = stats
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	status.setup(ContentDB.get_item(&"balance", &"default") as BalanceData, data is BossData)
	status.burned.connect(_on_burned)
	status.staggered.connect(_on_staggered)
	StatusBadge.attach(self, status, visual, data.body_radius + 3.0)
	if data.ai_script != null:
		ai = data.ai_script.new() as EnemyAI
	if ai == null:
		push_error("Enemy %s: ai_script is not an EnemyAI" % data.id)
		return
	ai.setup(self)


func _physics_process(delta: float) -> void:
	if _dead or ai == null:
		return
	status.tick(delta)
	knockback.tick(delta)
	if _dead:
		return
	# Set before the AI runs so an AI can override it (a stunned boar wobbles).
	visual.rotation = facing.angle()
	if status.is_held() and ai.can_be_held():
		if not _held:
			_held = true
			ai.interrupt()
		velocity = Vector2.ZERO
		apply_movement()
		return
	_held = false
	if _stun_time > 0.0:
		_stun_time -= delta
		move_toward_direction(Vector2.ZERO, delta)
	else:
		# Chill slows everything the AI does.
		ai.tick(delta * status.action_scale())


func is_dead() -> bool:
	return _dead


# --- Verbs for the AI --------------------------------------------------------

## The nearest living hero, or null.
func find_target() -> Node2D:
	var best: Node2D = null
	var best_distance: float = INF
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
		var hero: Hero = node as Hero
		if hero == null or hero.health.is_dead():
			continue
		var distance: float = global_position.distance_squared_to(hero.global_position)
		if distance < best_distance:
			best = hero
			best_distance = distance
	return best


## True if no wall blocks the straight line to `target`.
func can_see(target: Node2D) -> bool:
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position, target.global_position, WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Accelerates toward `direction` at the data's move speed (ZERO slows to a stop).
func move_toward_direction(direction: Vector2, delta: float) -> void:
	velocity = velocity.move_toward(direction * data.move_speed, ACCELERATION * delta)
	if direction != Vector2.ZERO:
		facing = direction.normalized()
	apply_movement()


## Moves with the current velocity (slowed by chill, stopped by root) plus any knockback.
func apply_movement() -> void:
	var own: Vector2 = velocity
	velocity = own * status.move_scale() + knockback.velocity
	move_and_slide()
	velocity = own


## True if the last movement bumped into a wall or pillar.
func hit_wall() -> bool:
	for i: int in get_slide_collision_count():
		var body: CollisionObject2D = get_slide_collision(i).get_collider() as CollisionObject2D
		if body != null and body.collision_layer & WORLD_LAYER:
			return true
	return false


func face(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing = direction.normalized()
	attack_pivot.rotation = facing.angle()


## Warns of a melee attack: a ring where the hitbox will land.
func telegraph_attack(attack: AttackData) -> void:
	attack_pivot.rotation = facing.angle()
	telegraph.position = facing * attack.reach
	telegraph.play(attack.radius, attack.windup)
	telegraph_started.emit()


## Warns of a cast from the enemy itself (a summon): a ring around its body.
func telegraph_attack_self(radius: float, duration: float) -> void:
	telegraph.position = Vector2.ZERO
	telegraph.play(radius, duration)
	telegraph_started.emit()


## Warns of something landing at a spot on the floor (world position).
func telegraph_at(world_position: Vector2, radius: float, duration: float, color: Color = TelegraphRing.SPORE_COLOR) -> void:
	clear_markers()
	var marker: TelegraphRing = TelegraphRing.new()
	marker.color = color
	get_parent().add_child(marker)
	marker.global_position = world_position
	marker.play(radius, duration)
	_markers.append(marker)
	telegraph_started.emit()


## Warns of several shots at once: a lane from the enemy along each direction.
func telegraph_lines(directions: Array[Vector2], length: float, width: float, duration: float) -> void:
	clear_markers()
	for direction: Vector2 in directions:
		var marker: TelegraphRing = TelegraphRing.new()
		marker.z_index = -1
		add_child(marker)
		marker.play_line(direction, length, width, duration)
		_markers.append(marker)
	telegraph_started.emit()


## Warns of a charge or shot along a lane starting at the enemy.
func telegraph_line(direction: Vector2, length: float, width: float, duration: float) -> void:
	telegraph.position = Vector2.ZERO
	telegraph.play_line(direction, length, width, duration)
	telegraph_started.emit()


func start_attack(attack: AttackData) -> void:
	attack_pivot.rotation = facing.angle()
	hitbox_shape.position = Vector2(attack.reach, 0.0)
	(hitbox_shape.shape as CircleShape2D).radius = attack.radius
	hitbox.activate(attack)
	if attack.shake > 0.0:
		EventBus.camera_shake_requested.emit(attack.shake)


func end_attack() -> void:
	hitbox.deactivate()


func cancel_attack() -> void:
	hitbox.deactivate()
	telegraph.stop()
	clear_markers()
	lash(0.0)


## Moves the live hitbox `length` px out along the facing and draws a line to it
## (Mother Toad's tongue). 0 pulls it back in.
func lash(length: float) -> void:
	hitbox_shape.position = Vector2(length, 0.0)
	if length <= 0.0:
		if _lash_line != null:
			_lash_line.hide()
		return
	if _lash_line == null:
		_lash_line = Line2D.new()
		_lash_line.default_color = TONGUE_COLOR
		_lash_line.width = 4.0
		_lash_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		_lash_line.end_cap_mode = Line2D.LINE_CAP_ROUND
		attack_pivot.add_child(_lash_line)
	_lash_line.points = PackedVector2Array([Vector2.ZERO, Vector2(length, 0.0)])
	_lash_line.show()


## In the air (a leap): no body collision and no hurtbox, drawn above everything.
func set_airborne(on: bool) -> void:
	body_shape.set_deferred("disabled", on)
	hurtbox_shape.set_deferred("disabled", on)
	z_index = 5 if on else 0


func is_airborne() -> bool:
	return z_index > 0


## A boss dropped below its enrage line: tells the room (a banner line).
func announce_enrage() -> void:
	enraged.emit()


## A boss's root wall centered on `world_position`, running along `along`.
func raise_root_wall(world_position: Vector2, along: Vector2) -> RootWall:
	var boss: BossData = data as BossData
	if boss == null or boss.root_wall == null:
		return null
	var wall: RootWall = ROOT_WALL_SCENE.instantiate()
	get_parent().add_child(wall)
	wall.global_position = world_position
	wall.reset_physics_interpolation()
	wall.setup(boss, along, stats, self)
	telegraph_started.emit()
	return wall


func fire_projectile(direction: Vector2) -> ThornArrow:
	var arrow: ThornArrow = ARROW_SCENE.instantiate()
	get_parent().add_child(arrow)
	arrow.global_position = global_position + direction * (data.body_radius + 2.0)
	arrow.reset_physics_interpolation()
	arrow.launch(direction, data, stats)
	return arrow


## Leaves the data's hazard (thorns, spore cloud) at a world position.
func drop_hazard(world_position: Vector2) -> ThornPatch:
	clear_markers()
	if data.hazard == null:
		return null
	var patch: ThornPatch = PATCH_SCENE.instantiate()
	patch.color = data.hazard_color
	get_parent().add_child(patch)
	patch.global_position = world_position
	patch.reset_physics_interpolation()
	patch.setup(data.hazard, data.hazard_lifetime, data.hazard_interval, stats)
	return patch


## Calls `count` minions around the enemy. Each is announced with `spawned` so the
## room's WaveDirector counts it before the room can clear.
func summon_minions(minion_data: EnemyData, count: int) -> Array[Enemy]:
	return _spawn_children(minion_data, count, SUMMON_SPREAD)


## Shake and flash for a self-inflicted stun (a boar hitting a wall).
func stun_feedback() -> void:
	EventBus.camera_shake_requested.emit(0.35)
	HitFlash.play(visual, 0.2)
	DamageNumber.spawn(get_parent(), global_position, "Stunned!", DamageNumber.COLOR_CRIT)


# --- Getting hit -------------------------------------------------------------

func _on_hurt(result: DamageResult, source: HitboxComponent) -> void:
	HitFlash.play(visual)
	var color: Color = DamageNumber.COLOR_CRIT if result.is_crit else DamageNumber.COLOR_NORMAL
	DamageNumber.spawn(get_parent(), global_position, str(result.amount), color, result.is_crit)
	var away: Vector2 = (global_position - source.global_position).normalized()
	knockback.apply(away * source.attack.knockback)
	if data.hit_stun > 0.0 and not health.is_dead():
		_stun_time = data.hit_stun
		ai.interrupt()


func _on_burned(amount: int) -> void:
	DamageNumber.spawn(get_parent(), global_position, str(amount), BURN_COLOR)


func _on_staggered() -> void:
	EventBus.camera_shake_requested.emit(0.25)
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -8), "Staggered!", DamageNumber.COLOR_CRIT)


func _on_died() -> void:
	_dead = true
	status.clear()
	cancel_attack()
	remove_from_group(GROUP)
	remove_from_group(AimAssist.GROUP)
	body_shape.set_deferred("disabled", true)
	_spawn_splits()
	died.emit(self)
	_play_death()


func _spawn_splits() -> void:
	if data.split_into == null or data.split_count <= 0:
		return
	_spawn_children(data.split_into, data.split_count, SPLIT_SPREAD)


func _spawn_children(child_data: EnemyData, count: int, spread: float) -> Array[Enemy]:
	var children: Array[Enemy] = []
	if child_data == null:
		return children
	for i: int in count:
		var child: Enemy = Enemy.create(child_data)
		var offset: Vector2 = Vector2.RIGHT.rotated(TAU * i / count + randf() * 0.5) * spread
		get_parent().add_child.call_deferred(child)
		child.position = position + offset
		child.ready.connect(func() -> void: child.knockback.apply(offset.normalized() * 140.0), CONNECT_ONE_SHOT)
		children.append(child)
		spawned.emit(child)
	return children


func clear_markers() -> void:
	for marker: TelegraphRing in _markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_markers.clear()


## Squash, spin and fade, then free.
func _play_death() -> void:
	HitFlash.play(visual, DEATH_TIME)
	telegraph.stop()
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(visual, "scale", Vector2(1.5, 0.6), 0.08)
	tween.tween_property(visual, "scale", Vector2.ZERO, DEATH_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(visual, "rotation", visual.rotation + PI, DEATH_TIME)
	tween.tween_callback(queue_free)


func _circle(radius: float) -> CircleShape2D:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	return shape
