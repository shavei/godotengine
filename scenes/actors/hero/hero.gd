class_name Hero
extends CharacterBody2D
## The player character (docs/ARCHITECTURE.md Section 7).
## Reads commands from an InputSource child, so tests, AI or a network peer can drive it.
## States live under StateMachine: Move, Attack, Dodge, Drink, Hurt, Dead.

const GROUP: StringName = &"heroes"

@export var player_id: int = 0
## Left empty, these load from ContentDB (weapon_sword, balance_default).
@export var weapon: WeaponData
@export var balance: BalanceData

var input: InputSource
var stamina: StaminaPool
var flasks: FlaskPouch
var stats: CombatStats = CombatStats.new()
## Direction the hero faces and aims (unit vector).
var facing: Vector2 = Vector2.RIGHT
## Index of the next swing in weapon.combo.
var combo_step: int = 0
## Counts down after a combo pause; when it runs out the combo restarts at step 0.
var combo_timer: float = 0.0

var _buffers: Dictionary = {}
var _iframe_time: float = 0.0

@onready var health: HealthComponent = $Health
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var knockback: KnockbackComponent = $Knockback
@onready var status: StatusComponent = $Status
@onready var state_machine: StateMachine = $StateMachine
@onready var visual: PlaceholderShape = $Visual
@onready var weapon_pivot: Node2D = $WeaponPivot
@onready var hitbox: HitboxComponent = $WeaponPivot/Hitbox
@onready var hitbox_shape: CollisionShape2D = $WeaponPivot/Hitbox/Shape
@onready var swing: SwingArc = $WeaponPivot/Swing


func _ready() -> void:
	add_to_group(GROUP)
	if balance == null:
		balance = ContentDB.get_item(&"balance", &"default") as BalanceData
	if balance == null:
		balance = BalanceData.new()
	if weapon == null:
		weapon = ContentDB.get_item(&"weapons", &"sword") as WeaponData
	input = _find_input_source()
	stamina = StaminaPool.new(balance.hero_max_stamina, balance.stamina_regen, balance.stamina_regen_delay)
	flasks = FlaskPouch.new(balance.flask_charges, balance.flask_heal_fraction)
	health.set_max_hp(balance.hero_max_hp, true)
	stats.weapon_tier = weapon.tier_multiplier if weapon != null else 1.0
	stats.crit_chance = balance.hero_crit_chance
	stats.crit_multiplier = balance.hero_crit_multiplier
	# Each hero gets its own shape because attacks resize it.
	hitbox_shape.shape = CircleShape2D.new()
	hitbox.stats = stats
	hurtbox.stats = stats
	hurtbox.hurt.connect(_on_hurt)
	hitbox.hit_landed.connect(_on_hit_landed)
	health.died.connect(_on_died)
	state_machine.start(self)


func _physics_process(delta: float) -> void:
	_read_input(delta)
	stamina.tick(delta)
	status.tick(delta)
	knockback.tick(delta)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo_step = 0
	if _iframe_time > 0.0:
		_iframe_time -= delta
	hurtbox.invincible = _iframe_time > 0.0
	state_machine.physics_update(delta)
	_update_visuals()


# --- Input -----------------------------------------------------------------

## Returns true once for a buffered press of `action` and clears it.
func consume(action: StringName) -> bool:
	return _buffers.erase(action)


func is_buffered(action: StringName) -> bool:
	return _buffers.has(action)


func aim_direction() -> Vector2:
	var aim: Vector2 = input.get_aim(global_position)
	if aim == Vector2.ZERO:
		aim = input.get_move().normalized()
	return aim if aim != Vector2.ZERO else facing


func update_facing() -> void:
	facing = aim_direction()


## Starts a dodge, attack or flask if one is buffered and allowed. Returns true if it did.
func try_start_action() -> bool:
	if try_dodge():
		return true
	if weapon != null and not weapon.combo.is_empty() and consume(&"attack"):
		state_machine.transition_to(&"Attack")
		return true
	if is_buffered(&"flask"):
		consume(&"flask")
		if flasks.can_drink(health.hp, health.max_hp):
			state_machine.transition_to(&"Drink")
			return true
	return false


## Starts a buffered dodge if there is enough stamina. Returns true if it did.
func try_dodge() -> bool:
	if not is_buffered(&"dodge") or not stamina.try_spend(balance.dodge_stamina_cost):
		return false
	consume(&"dodge")
	state_machine.transition_to(&"Dodge")
	return true


# --- Movement --------------------------------------------------------------

## Accelerates toward the input direction. `speed_scale` slows the hero (drinking).
func move_with_input(delta: float, speed_scale: float = 1.0) -> void:
	var dir: Vector2 = input.get_move()
	var target: Vector2 = dir * balance.hero_move_speed * speed_scale
	var rate: float = balance.hero_acceleration if dir != Vector2.ZERO else balance.hero_friction
	velocity = velocity.move_toward(target, rate * delta)
	apply_movement()


## Moves with the current velocity plus any knockback.
func apply_movement() -> void:
	var own: Vector2 = velocity
	velocity = own + knockback.velocity
	move_and_slide()
	velocity = own


# --- Combat ----------------------------------------------------------------

func grant_iframes(duration: float) -> void:
	_iframe_time = maxf(_iframe_time, duration)


func has_iframes() -> bool:
	return _iframe_time > 0.0


func _on_hurt(result: DamageResult, source: HitboxComponent) -> void:
	var away: Vector2 = (global_position - source.global_position).normalized()
	knockback.apply(away * source.attack.knockback)
	grant_iframes(balance.hurt_iframes)
	HitFlash.play(visual, 0.15)
	DamageNumber.spawn(get_parent(), global_position, str(result.amount), DamageNumber.COLOR_HERO, result.is_crit)
	EventBus.camera_shake_requested.emit(0.4)
	HitStop.request(get_tree(), 0.05)
	combo_step = 0
	if not health.is_dead():
		state_machine.transition_to(&"Hurt")


func _on_hit_landed(_hurtbox: HurtboxComponent, result: DamageResult) -> void:
	var attack: AttackData = hitbox.attack
	var shake: float = attack.shake + (0.15 if result.is_crit else 0.0)
	EventBus.camera_shake_requested.emit(shake)
	HitStop.request(get_tree(), attack.hit_stop + (0.03 if result.is_crit else 0.0))


func _on_died() -> void:
	state_machine.transition_to(&"Dead")
	EventBus.hero_died.emit(player_id)


# --- Internals -------------------------------------------------------------

func _read_input(delta: float) -> void:
	for action: StringName in _buffers.keys():
		_buffers[action] -= delta
		if _buffers[action] <= 0.0:
			_buffers.erase(action)
	for action: StringName in [&"attack", &"dodge", &"flask"]:
		if input.just_pressed(action):
			_buffers[action] = balance.input_buffer


func _update_visuals() -> void:
	visual.rotation = facing.angle()
	if not state_machine.is_in(&"Attack"):
		weapon_pivot.rotation = facing.angle()
	if state_machine.is_in(&"Dodge"):
		visual.modulate.a = 0.55
	elif has_iframes() and not health.is_dead():
		# Blink during the grace period after a hit.
		visual.modulate.a = 0.35 if int(_iframe_time * 20.0) % 2 == 0 else 1.0
	else:
		visual.modulate.a = 1.0


func _find_input_source() -> InputSource:
	for child: Node in get_children():
		if child is InputSource:
			return child
	var local: LocalInputSource = LocalInputSource.new()
	local.name = "LocalInput"
	add_child(local)
	return local
