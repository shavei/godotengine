class_name TrainingDummy
extends StaticBody2D
## Practice target for the test room (and the onboarding yard later, GDD Section 16).
## Never stays dead. With a counterattack set, it telegraphs a slam when the hero is close,
## which is handy for practicing dodge timing.

@export var counterattack: AttackData
## The dummy only slams when a hero is this close (px).
@export var trigger_range: float = 60.0
@export var slam_cooldown: float = 1.6
## Seconds without being hit before HP resets.
@export var reset_delay: float = 2.5

enum Phase { IDLE, TELEGRAPH, STRIKE, COOLDOWN }

const REVIVE_DELAY: float = 0.4

var _phase: Phase = Phase.IDLE
var _phase_time: float = 0.0
var _since_hit: float = 0.0

@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: HitboxComponent = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape
@onready var visual: PlaceholderShape = $Visual
@onready var telegraph: TelegraphRing = $Telegraph


func _ready() -> void:
	add_to_group(AimAssist.GROUP)
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	if counterattack != null:
		var shape: CircleShape2D = CircleShape2D.new()
		shape.radius = counterattack.radius
		hitbox_shape.shape = shape
		visual.color = Color(0.75, 0.42, 0.35)


func _physics_process(delta: float) -> void:
	_since_hit += delta
	if _since_hit >= reset_delay and health.hp < health.max_hp:
		health.reset()
	if counterattack != null:
		_update_slam(delta)


func _update_slam(delta: float) -> void:
	_phase_time += delta
	match _phase:
		Phase.IDLE:
			if _hero_in_range():
				_set_phase(Phase.TELEGRAPH)
				telegraph.play(counterattack.radius, counterattack.windup)
		Phase.TELEGRAPH:
			if _phase_time >= counterattack.windup:
				_set_phase(Phase.STRIKE)
				hitbox.activate(counterattack)
				EventBus.camera_shake_requested.emit(counterattack.shake)
		Phase.STRIKE:
			if _phase_time >= counterattack.active:
				hitbox.deactivate()
				_set_phase(Phase.COOLDOWN)
		Phase.COOLDOWN:
			if _phase_time >= slam_cooldown:
				_set_phase(Phase.IDLE)


func _set_phase(phase: Phase) -> void:
	_phase = phase
	_phase_time = 0.0


func _hero_in_range() -> bool:
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
		var hero: Node2D = node as Node2D
		if hero != null and global_position.distance_to(hero.global_position) <= trigger_range:
			return true
	return false


func _on_hurt(result: DamageResult, source: HitboxComponent) -> void:
	_since_hit = 0.0
	HitFlash.play(visual)
	var color: Color = DamageNumber.COLOR_CRIT if result.is_crit else DamageNumber.COLOR_NORMAL
	DamageNumber.spawn(get_parent(), global_position, str(result.amount), color, result.is_crit)
	# Wobble away from the hit.
	var side: float = signf(global_position.x - source.global_position.x)
	var tween: Tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(visual, "rotation", 0.25 * (side if side != 0.0 else 1.0), 0.05)
	tween.tween_property(visual, "rotation", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_died() -> void:
	# Dummies pop back up shortly after (the reset in _physics_process does it).
	_since_hit = reset_delay - REVIVE_DELAY
