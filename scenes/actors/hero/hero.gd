class_name Hero
extends CharacterBody2D
## The player character (docs/ARCHITECTURE.md Section 7).
## Reads commands from an InputSource child, so tests, AI or a network peer can drive it.
## States live under StateMachine: Move, Attack, Dodge, Drink, Cast, Hurt, Dead.
## Kept powers sit in `powers` (a PowerLoadout), one per Power button.
## Village services (a ModifierStack) change a run's hero: max HP, flasks, revive tokens,
## weapon infusions, damage taken (apply_services). The Techniques Masters taught join
## the same stack (heal on a kill, thorns, steady footing, HP-based power damage and swing
## speed); a Technique that is more than numbers rides along as a TechniqueBehavior child
## (apply_techniques).

## Dodge was pressed without enough stamina (the HUD flashes the bar).
signal dodge_denied
## A Power button was pressed for an empty slot or one still cooling down.
signal power_denied(slot: int)
## A power went off (its cooldown has started).
signal power_cast(slot: int)
## A revive token was used: the hero got up instead of falling.
signal revived
signal revives_changed(count: int)
## A dodge started (Ember Step listens).
signal dodge_started
## A dodge rolled through an attack: once per dodge (Cold Temper listens).
signal perfect_dodge(source: HitboxComponent)

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
const REVIVE_COLOR: Color = Color(1, 0.85, 0.5)
const REVIVE_BLAST_COLOR: Color = Color(1, 0.5, 0.2)
const TECHNIQUE_COLOR: Color = Color(1, 0.82, 0.45)

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
## What the village does for this hero in a run (empty outside runs).
var services: ModifierStack = ModifierStack.new()
## Revive tokens left this run.
var revives: int = 0
## Flasks left on this floor that are not used up when drunk (Second Serving).
var free_flasks: int = 0
## Swing speed (1 = normal); Fever raises it at low HP.
var attack_speed: float = 1.0
## Rolls weapon infusions.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Direction the hero faces and aims (unit vector).
var facing: Vector2 = Vector2.RIGHT
## Index of the next swing in weapon.combo.
var combo_step: int = 0
## Counts down after a combo pause; when it runs out the combo restarts at step 0.
var combo_timer: float = 0.0

var _buffers: Dictionary = {}
var _iframe_time: float = 0.0
## Max HP and weapon damage bonus from progress alone, before services.
var _progress_max_hp: int = 0
var _progress_damage_bonus: float = 0.0
## A Growth Farmer's flask: HP still to heal over time, per second, and the fraction owed.
var _regen_left: float = 0.0
var _regen_rate: float = 0.0
var _regen_owed: float = 0.0
## Power damage from Focus alone, before Techniques.
var _focus_bonus: float = 0.0
## The room's conditions (a boss room), for the HP-based ones to join.
var _room_conditions: Array[StringName] = []
## The first hit in this room has not landed yet (Anvil Skin).
var _first_hit_pending: bool = false
## Seconds left that weapon hits Burn after a flask (Hearth Heart).
var _hearth_time: float = 0.0
## HP owed from regeneration out of combat (Regrowth).
var _calm_owed: float = 0.0
## This dodge already rolled through an attack.
var _perfect_this_dodge: bool = false
## Deals thorn damage to attackers.
var _thorns: HitboxComponent

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
	rng.randomize()
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
	hurtbox.dodged.connect(_on_dodged)
	health.health_changed.connect(_on_health_changed)
	hitbox.hit_landed.connect(_on_hit_landed)
	health.died.connect(_on_died)
	state_machine.start(self)


func _physics_process(delta: float) -> void:
	_read_input(delta)
	stamina.tick(delta)
	powers.tick(delta)
	status.tick(delta)
	knockback.tick(delta)
	_tick_regen(delta)
	_tick_techniques(delta)
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


## Applies the hero's long-term progress (level, Vigor, Might, Focus, weapon tier, kept
## powers) and refills HP and stamina.
func apply_progress(progress: HeroState) -> void:
	_progress_max_hp = ProgressionSystem.max_hp(progress, balance)
	health.set_max_hp(_progress_max_hp, true)
	stamina.maximum = ProgressionSystem.max_stamina(progress, balance)
	stamina.current = stamina.maximum
	_progress_damage_bonus = ProgressionSystem.weapon_damage_bonus(progress, balance)
	stats.damage_bonus = _progress_damage_bonus
	if weapon != null:
		stats.weapon_tier = weapon.tier_multiplier * ShopSystem.tier_multiplier(progress.weapon_tier(weapon.id), balance)
	focus = progress.attribute(HeroState.FOCUS)
	_focus_bonus = PowerRules.focus_damage_bonus(focus, balance)
	power_stats.damage_bonus = _focus_bonus
	equip_powers(progress.kept_powers)


## Applies the village's services for a run (after apply_progress): max HP, flask
## charges and heal, damage taken (`conditions` like ModifierStack.BOSS_ROOM switch on
## the matching ones), and a full set of revive tokens. Refills HP and flasks.
func apply_services(stack: ModifierStack, conditions: Array[StringName] = []) -> void:
	services = stack if stack != null else ModifierStack.new()
	if _progress_max_hp <= 0:
		_progress_max_hp = health.max_hp
	var max_hp: float = services.total(ModifierStack.MAX_HP, _progress_max_hp) * (1.0 + services.total(ModifierStack.MAX_HP_SHARE))
	health.set_max_hp(roundi(max_hp), true)
	flasks.max_charges = maxi(0, services.count(ModifierStack.FLASK_CHARGES, balance.flask_charges))
	flasks.heal_fraction = balance.flask_heal_fraction * (1.0 + services.total(ModifierStack.FLASK_HEAL))
	flasks.refill()
	_room_conditions = conditions.duplicate()
	_first_hit_pending = services.has(ModifierStack.FIRST_HIT_TAKEN)
	free_flasks = maxi(0, services.count(ModifierStack.FREE_FLASKS))
	_hearth_time = 0.0
	set_revives(services.count(ModifierStack.REVIVES))
	set_mending(0)
	refresh_conditional_stats()


## The conditions that hold right now: the room's, plus low_hp and half_hp from HP.
func active_conditions() -> Array[StringName]:
	var result: Array[StringName] = _room_conditions.duplicate()
	var share: float = float(health.hp) / maxf(1.0, health.max_hp)
	if share < balance.low_hp_fraction:
		result.append(ModifierStack.LOW_HP)
	if share < balance.half_hp_fraction:
		result.append(ModifierStack.HALF_HP)
	return result


## Recomputes what depends on HP and the first hit: damage taken, power damage, swing speed.
func refresh_conditional_stats() -> void:
	var now: Array[StringName] = active_conditions()
	var taken: float = 1.0 + services.total(ModifierStack.DAMAGE_TAKEN, 0.0, now)
	if _first_hit_pending:
		taken += services.total(ModifierStack.FIRST_HIT_TAKEN, 0.0, now)
	stats.damage_taken_multiplier = maxf(0.0, taken)
	power_stats.damage_bonus = _focus_bonus + services.total(ModifierStack.POWER_DAMAGE, 0.0, now)
	attack_speed = maxf(0.1, 1.0 + services.total(ModifierStack.ATTACK_SPEED, 0.0, now))


## Adds the behaviors of the hero's Techniques (those with a script), replacing any from
## before. Modifiers come with the ModifierStack in apply_services.
func apply_techniques(techniques: Array[TechniqueData]) -> void:
	for child: Node in get_children():
		if child is TechniqueBehavior:
			remove_child(child)
			child.queue_free()
	for technique: TechniqueData in techniques:
		if technique == null or technique.behavior_script == null:
			continue
		var behavior: TechniqueBehavior = technique.behavior_script.new() as TechniqueBehavior
		if behavior == null:
			push_error("Technique %s: behavior_script is not a TechniqueBehavior" % technique.id)
			continue
		behavior.attach(self, technique)
		add_child(behavior)


## The Techniques' behaviors the hero carries now.
func technique_behaviors() -> Array[TechniqueBehavior]:
	var result: Array[TechniqueBehavior] = []
	for child: Node in get_children():
		if child is TechniqueBehavior and not child.is_queued_for_deletion():
			result.append(child)
	return result


func set_revives(count: int) -> void:
	revives = maxi(0, count)
	revives_changed.emit(revives)


## Weapon damage from fight rooms cleared in a row without being hit (a Growth Smith's
## self-mending gear): a step per room, up to the cap.
func set_mending(rooms: int) -> void:
	stats.damage_bonus = _progress_damage_bonus + mending_bonus(rooms)


func mending_bonus(rooms: int) -> float:
	return minf(rooms * services.total(ModifierStack.MENDING_STEP), services.total(ModifierStack.MENDING_CAP))


## Uses a revive token if one is left: back up with a share of max HP and a moment of
## grace (a Fire Healer's revive also bursts into flame). Returns true if it did.
func try_revive() -> bool:
	if revives <= 0:
		return false
	set_revives(revives - 1)
	var fraction: float = balance.revive_hp_fraction + services.total(ModifierStack.REVIVE_HP)
	health.revive(maxi(1, roundi(health.max_hp * fraction)))
	status.clear()
	grant_iframes(balance.revive_iframes)
	var blast: float = services.total(ModifierStack.REVIVE_BLAST)
	if blast > 0.0 and is_inside_tree():
		var attack: AttackData = AttackData.new()
		attack.damage = blast
		attack.radius = balance.revive_blast_radius
		attack.knockback = 160.0
		attack.shake = 0.5
		attack.status = StatusEffects.BURN
		PowerBurst.spawn(get_parent(), global_position, attack, power_stats, REVIVE_BLAST_COLOR)
	if is_inside_tree():
		DamageNumber.spawn(get_parent(), global_position + Vector2(0, -16), "Revived!", REVIVE_COLOR)
	revived.emit()
	EventBus.hero_revived.emit(player_id)
	return true


## A flask was drunk (`healed` HP): a Growth Farmer's flask keeps healing, Hearth Heart
## makes weapon hits Burn for a while, and Second Serving gives the charge back.
func flask_drunk(_healed: int) -> void:
	start_flask_regen()
	var burn_time: float = services.total(ModifierStack.FLASK_BURN_TIME)
	if burn_time > 0.0:
		_hearth_time = burn_time
	if free_flasks > 0:
		free_flasks -= 1
		flasks.refill(1)
		_technique_text("Free flask!")


## A Growth Farmer's flask keeps healing: its share of max HP over flask_regen_time.
func start_flask_regen() -> void:
	var share: float = services.total(ModifierStack.FLASK_REGEN)
	if share <= 0.0 or balance.flask_regen_time <= 0.0:
		return
	_regen_left += health.max_hp * share
	_regen_rate = _regen_left / balance.flask_regen_time


func is_regenerating() -> bool:
	return _regen_left > 0.0


func _tick_techniques(delta: float) -> void:
	if _hearth_time > 0.0:
		_hearth_time = maxf(0.0, _hearth_time - delta)
	var calm: float = services.total(ModifierStack.CALM_REGEN)
	if calm <= 0.0 or health.is_dead() or health.hp >= health.max_hp or not is_inside_tree():
		_calm_owed = 0.0
		return
	if not get_tree().get_nodes_in_group(Enemy.GROUP).is_empty():
		_calm_owed = 0.0
		return
	_calm_owed += calm * delta
	if _calm_owed >= 1.0:
		var whole: int = floori(_calm_owed)
		_calm_owed -= whole
		health.heal(whole)


## Hearth Heart's burning hits are on.
func is_hearth_burning() -> bool:
	return _hearth_time > 0.0


func _tick_regen(delta: float) -> void:
	if _regen_left <= 0.0 or health.is_dead():
		return
	var step: float = minf(_regen_rate * delta, _regen_left)
	_regen_left -= step
	_regen_owed += step
	if _regen_owed >= 1.0:
		var whole: int = floori(_regen_owed)
		_regen_owed -= whole
		health.heal(whole)


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


## The Dodge state began a roll.
func on_dodge_started() -> void:
	_perfect_this_dodge = false
	dodge_started.emit()


## Hits never knock the hero back or stagger them right now (Iron Bones, or Rooted
## Stance while attacking).
func is_steady() -> bool:
	if services.total(ModifierStack.STEADY) > 0.0:
		return true
	return services.total(ModifierStack.STEADY_ATTACKS) > 0.0 and state_machine.is_in(&"Attack")


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
	var steady: bool = is_steady()
	if _first_hit_pending:
		_first_hit_pending = false
		refresh_conditional_stats()
	_answer_attacker(source)
	if not steady:
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
	if steady:
		return
	combo_step = 0
	if not health.is_dead():
		state_machine.transition_to(&"Hurt")


## An enemy that hit the hero up close (its own attack, not an arrow) is Chilled (Hold the
## Line) and takes thorn damage (Thornmail).
func _answer_attacker(source: HitboxComponent) -> void:
	var attacker: Enemy = _attacker_of(source)
	if attacker == null or attacker.health.is_dead():
		return
	if services.total(ModifierStack.CHILL_ATTACKERS) > 0.0:
		attacker.hurtbox.receive_status(StatusEffects.CHILL)
	var thorns: float = services.total(ModifierStack.THORNS)
	if thorns > 0.0:
		if _thorns == null:
			_thorns = HitboxComponent.new()
			_thorns.name = "Thorns"
			_thorns.attack = AttackData.new()
			_thorns.stats.crit_chance = 0.0
			add_child(_thorns)
			_thorns.monitoring = false
		_thorns.attack.damage = thorns
		_thorns.attack.knockback = 40.0
		attacker.hurtbox.receive_hit(_thorns)


## The enemy whose own hitbox this is, or null (arrows, thorn patches, root walls).
func _attacker_of(source: HitboxComponent) -> Enemy:
	var node: Node = source.get_parent() if source != null else null
	while node != null:
		if node is Enemy:
			return node
		if node is Hero or node == get_tree().current_scene:
			return null
		node = node.get_parent()
	return null


func _on_dodged(source: HitboxComponent) -> void:
	if _perfect_this_dodge or not state_machine.is_in(&"Dodge"):
		return
	_perfect_this_dodge = true
	perfect_dodge.emit(source)


func _on_health_changed(_current: int, _maximum: int) -> void:
	refresh_conditional_stats()


func _on_hit_landed(target: HurtboxComponent, result: DamageResult) -> void:
	var attack: AttackData = hitbox.attack
	var shake: float = attack.shake + (0.15 if result.is_crit else 0.0)
	EventBus.camera_shake_requested.emit(shake)
	HitStop.request(get_tree(), attack.hit_stop + (0.03 if result.is_crit else 0.0))
	# Rumble follows the shake: light taps for slashes, a thump for the finisher.
	rumble(clampf(shake * 1.5, 0.1, 1.0), 0.06 + attack.hit_stop)
	apply_infusions(target, attack)
	var heal: int = services.count(ModifierStack.HEAL_ON_KILL)
	if heal > 0 and target != null and target.health != null and target.health.is_dead():
		var healed: int = health.heal(heal)
		if healed > 0 and is_inside_tree():
			DamageNumber.spawn(get_parent(), global_position + Vector2(0, -16), "+%d" % healed, DamageNumber.COLOR_HEAL)


## A Smith's infusion on weapon hits: a chance to Burn or Chill, and extra stagger.
func apply_infusions(target: HurtboxComponent, attack: AttackData) -> void:
	if target == null:
		return
	if is_hearth_burning() or rng.randf() < services.total(ModifierStack.WEAPON_BURN_CHANCE):
		target.receive_status(StatusEffects.BURN)
	if rng.randf() < services.total(ModifierStack.WEAPON_CHILL_CHANCE):
		target.receive_status(StatusEffects.CHILL)
	var extra_stagger: float = attack.stagger * services.total(ModifierStack.WEAPON_STAGGER) if attack != null else 0.0
	if extra_stagger > 0.0:
		target.receive_status(&"", 0, extra_stagger)


func _on_died() -> void:
	if try_revive():
		return
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


## A short gold word over the hero when a Technique acts.
func _technique_text(text: String) -> void:
	if is_inside_tree():
		DamageNumber.spawn(get_parent(), global_position + Vector2(0, -20), text, TECHNIQUE_COLOR)


func _find_input_source() -> InputSource:
	for child: Node in get_children():
		if child is InputSource:
			return child
	var local: LocalInputSource = LocalInputSource.new()
	local.name = "LocalInput"
	add_child(local)
	return local
