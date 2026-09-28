class_name StatusComponent
extends Node
## Status effects on one actor (burn, chill, freeze, root, stun). The rules live in
## StatusEffects; this node ticks them, deals burn damage to the linked HealthComponent
## and tells the owner what changed. The owner calls tick() from its _physics_process.

signal status_added(id: StringName)
signal status_removed(id: StringName)
## Burn damage was dealt this frame.
signal burned(amount: int)
## The stagger bar filled up and the actor is stunned.
signal staggered

## Takes burn damage. Left empty, burns are tracked but deal nothing.
@export var health: HealthComponent

var effects: StatusEffects


func _ready() -> void:
	if effects == null:
		setup(ContentDB.get_item(&"balance", &"default") as BalanceData, false)


## Picks the numbers and the boss rules. Call again if the owner turns out to be a boss.
func setup(balance: BalanceData, is_boss: bool) -> void:
	effects = StatusEffects.new(balance, is_boss)
	effects.status_added.connect(func(id: StringName) -> void: status_added.emit(id))
	effects.status_removed.connect(func(id: StringName) -> void: status_removed.emit(id))
	effects.staggered.connect(func() -> void: staggered.emit())


func apply(id: StringName, count: int = 1) -> void:
	_ensure()
	effects.apply(id, count)


func add_stagger(amount: float) -> void:
	_ensure()
	effects.add_stagger(amount)


func has(id: StringName) -> bool:
	return effects != null and effects.has(id)


func stacks(id: StringName) -> int:
	return effects.stacks(id) if effects != null else 0


func is_held() -> bool:
	return effects != null and effects.is_held()


func move_scale() -> float:
	return effects.move_scale() if effects != null else 1.0


func action_scale() -> float:
	return effects.action_scale() if effects != null else 1.0


func clear() -> void:
	if effects != null:
		effects.clear()


func tick(delta: float) -> void:
	if effects == null:
		return
	var damage: int = effects.tick(delta)
	if damage > 0 and health != null and not health.is_dead():
		health.take_damage(damage)
		burned.emit(damage)


func _ensure() -> void:
	if effects == null:
		setup(null, false)
