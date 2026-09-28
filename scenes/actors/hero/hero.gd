class_name Hero
extends CharacterBody2D
## The player character (docs/ARCHITECTURE.md Section 7).
## Reads commands from an InputSource child, so tests, AI or a network peer can drive it.
## States live under StateMachine: Move, Attack, Dodge, Drink, Cast, Hurt, Dead.
## Kept powers sit in `powers` (a PowerLoadout), one per Power button.

## Dodge was pressed without enough stamina (the HUD flashes the bar).
signal dodge_denied
## A Power button was pressed for an empty slot or one still cooling down.
signal power_denied(slot: int)
## A power went off (its cooldown has started).
signal power_cast(slot: int)

const GROUP: StringName = &"heroes"
## Physics layer number of enemy bodies (docs/ARCHITECTURE.md Section 7).
const ENEMY_BODY_LAYER: int = 3
## Rumble (strength, seconds) when the hero is hit.
const HURT_RUMBLE: Vector2 = Vector2(0.6, 0.18)
## With no aim input the hero faces where it moves, but only when the move stick is
## pushed at least this far. Letting go of a stick (and its spring-back) never turns it.
const FACE_MIN_TILT: float = 0.5
## Input actions of the power slots, in slot order.
const POWER_ACTIONS: Array[StringName] = [&"power_1", &"power_2", &"power_3"]
const BUFFERED_ACTIONS: Array[StringName] = [&"attack", &"dodge", &"flask", &"power_1", &"power_2", &"power_3"]
const BLOCK_COLOR: Color = Color(0.8, 0.72, 0.6)

@export var player_id: int = 0
## Left empty, these load from ContentDB (weapon_sword, balance_default).
@export var weapon: WeaponData
@export var balance: BalanceData

var input: InputSource
var stamina: StaminaPool
var flasks: FlaskPouch
var stats: CombatStats = CombatStats.new()
## Offense numbers for power hits: base crit, Focus bonus, never the weapon tier.
var power_stats: CombatStats = CombatStats.new()
var powers: PowerLoadout
## Focus points (power damage is in power_stats; cooldowns read this).
var focus: int = 0
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
	powers = PowerLoadout.new(GiftSystem.slot_count(balance))
	health.set_max_hp(balance.hero_max_hp, true)
	stats.weapon_tier = weapon.tier_multiplier if weapon != null else 1.0
	apply_balance()
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
	powers.tick(delta)
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
	if aim != Vector2.ZERO:
		return aim
	var move: Vector2 = input.get_move()
	if move.length() >= FACE_MIN_TILT:
		return move.normalized()
	return facing


func update_facing() -> void:
	facing = aim_direction()


## Aim for a new swing: stick aim turns toward a close target (AimAssist).
func attack_direction() -> Vector2:
	return _assisted_aim(balance.aim_assist_angle, balance.aim_assist_range)


## Aim for a cast: stick aim turns toward a target within the power's reach, so a
## fireball can find an enemy far beyond sword range.
func power_direction(power: PowerData) -> Vector2:
	var reach: float = maxf(power.projectile_range, balance.aim_assist_range) if power != null else balance.aim_assist_range
	return _assisted_aim(balance.power_aim_assist_angle, reach)


func _assisted_aim(max_angle: float, max_range: float) -> Vector2:
	var aim: Vector2 = aim_direction()
	if not input.wants_aim_assist():
		return aim
	var targets: Array[Vector2] = []
	for node: Node in get_tree().get_nodes_in_group(AimAssist.GROUP):
		var target: Node2D = node as Node2D
		if target != null:
			targets.append(target.global_position)
	return AimAssist.pick(global_position, aim, targets, max_angle, max_range)


## Copies live BalanceData numbers into the helpers that keep their own copy
## (the F4 tuning panel calls this after a change).
func apply_balance() -> void:
	stamina.regen_per_second = balance.stamina_regen
	stamina.regen_delay = balance.stamina_regen_delay
	stats.crit_chance = balance.hero_crit_chance
	stats.crit_multiplier = balance.hero_crit_multiplier
	power_stats.crit_chance = balance.hero_crit_chance
	power_stats.crit_multiplier = balance.hero_crit_multiplier


## Applies the hero's long-term progress (level, Vigor, Might, Focus, kept powers) and
## refills HP and stamina.
func apply_progress(progress: HeroState) -> void:
	health.set_max_hp(ProgressionSystem.max_hp(progress, balance), true)
	stamina.maximum = ProgressionSystem.max_stamina(progress, balance)
	stamina.current = stamina.maximum
	stats.damage_bonus = ProgressionSystem.weapon_damage_bonus(progress, balance)
	focus = progress.attribute(HeroState.FOCUS)
	power_stats.damage_bonus = PowerRules.focus_damage_bonus(focus, balance)
	equip_powers(progress.kept_powers)


## Fills the power slots from kept powers (PowerData from ContentDB), in slot order.
func equip_powers(kept: Array[KeptPower]) -> void:
	var list: Array[PowerData] = []
	var levels: Array[int] = []
	for entry: KeptPower in kept:
		var power: PowerData = ContentDB.get_item(&"powers", entry.power_id) as PowerData
		if power == null:
			push_warning("Hero: unknown kept power %s" % entry.power_id)
			continue
		list.append(power)
		levels.append(entry.level)
	powers.set_powers(list, levels)


## Casts the power in `slot` toward the facing and starts its cooldown.
func cast_power(slot: int) -> void:
	var entry: PowerLoadout.Slot = powers.slot(slot)
	if entry == null or entry.power.ability_script == null:
		return
	var ability: Ability = entry.power.ability_script.new() as Ability
	if ability == null:
		push_error("Power %s: ability_script is not an Ability" % entry.power.id)
		return
	ability.cast(self, entry.power, entry.level, facing)
	powers.start_cooldown(slot, PowerRules.cooldown(entry.power, focus, balance))
	power_cast.emit(slot)


func rumble(strength: float, duration: float) -> void:
	input.rumble(strength * balance.rumble_strength, duration)


## Starts a dodge, attack or flask if one is buffered and allowed. Returns true if it did.
func try_start_action() -> bool:
	if try_dodge():
		return true
	if try_cast():
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


## Starts a buffered power cast if that slot is ready. Returns true if it did.
func try_cast() -> bool:
	for slot: int in POWER_ACTIONS.size():
		if not consume(POWER_ACTIONS[slot]):
			continue
		if powers.is_ready(slot):
			state_machine.transition_to(&"Cast", {"slot": slot})
			return true
		power_denied.emit(slot)
	return false


# --- Movement --------------------------------------------------------------

## Accelerates toward the input direction. `speed_scale` slows the hero (drinking).
func move_with_input(delta: float, speed_scale: float = 1.0) -> void:
	velocity = steer(velocity, input.get_move() * balance.hero_move_speed * speed_scale, balance, delta)
	apply_movement()


## Moves `current` toward `target` velocity: speeds up at acceleration, stops at friction,
## and turning against the current motion uses both, so a reversal is as quick as a stop.
static func steer(current: Vector2, target: Vector2, tuning: BalanceData, delta: float) -> Vector2:
	var rate: float = tuning.hero_friction
	if target != Vector2.ZERO:
		rate = tuning.hero_acceleration
		if current.dot(target) < 0.0:
			rate += tuning.hero_friction
	return current.move_toward(target, rate * delta)


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
	if health.last_absorbed >= result.amount:
		# The shield took all of it: no stagger, just a thud.
		DamageNumber.spawn(get_parent(), global_position, "Blocked", BLOCK_COLOR)
		EventBus.camera_shake_requested.emit(0.2)
		return
	HitFlash.play(visual, 0.15)
	DamageNumber.spawn(get_parent(), global_position, str(result.amount), DamageNumber.COLOR_HERO, result.is_crit)
	EventBus.camera_shake_requested.emit(0.4)
	HitStop.request(get_tree(), 0.05)
	rumble(HURT_RUMBLE.x, HURT_RUMBLE.y)
	combo_step = 0
	if not health.is_dead():
		state_machine.transition_to(&"Hurt")


func _on_hit_landed(_hurtbox: HurtboxComponent, result: DamageResult) -> void:
	var attack: AttackData = hitbox.attack
	var shake: float = attack.shake + (0.15 if result.is_crit else 0.0)
	EventBus.camera_shake_requested.emit(shake)
	HitStop.request(get_tree(), attack.hit_stop + (0.03 if result.is_crit else 0.0))
	# Rumble follows the shake: light taps for slashes, a thump for the finisher.
	rumble(clampf(shake * 1.5, 0.1, 1.0), 0.06 + attack.hit_stop)


func _on_died() -> void:
	state_machine.transition_to(&"Dead")
	EventBus.hero_died.emit(player_id)


# --- Internals -------------------------------------------------------------

func _read_input(delta: float) -> void:
	for action: StringName in _buffers.keys():
		_buffers[action] -= delta
		if _buffers[action] <= 0.0:
			_buffers.erase(action)
	for action: StringName in BUFFERED_ACTIONS:
		if input.just_pressed(action):
			_buffers[action] = balance.input_buffer
			if action == &"dodge" and not stamina.can_spend(balance.dodge_stamina_cost):
				dodge_denied.emit()


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
