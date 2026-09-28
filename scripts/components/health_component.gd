class_name HealthComponent
extends Node
## Hit points for any actor. The owner listens to the signals; nothing here knows about visuals.

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died
## The shield soaked up damage or changed size.
signal shield_changed(shield: int)

@export var max_hp: int = 100

var hp: int = 0
## Soaks up damage before HP does (Stone's Bulwark).
var shield: int = 0
## How much of the last hit the shield soaked up.
var last_absorbed: int = 0


func _ready() -> void:
	hp = max_hp


func is_dead() -> bool:
	return hp <= 0


## Applies damage (the shield soaks it up first) and returns how much HP was lost.
func take_damage(amount: int) -> int:
	last_absorbed = 0
	if amount <= 0 or is_dead():
		return 0
	if shield > 0:
		last_absorbed = mini(shield, amount)
		shield -= last_absorbed
		amount -= last_absorbed
		shield_changed.emit(shield)
		if amount <= 0:
			return 0
	var taken: int = mini(amount, hp)
	hp -= taken
	damaged.emit(taken)
	health_changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
	return taken


## Heals and returns how much was actually restored. The dead cannot be healed.
func heal(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var restored: int = mini(amount, max_hp - hp)
	if restored == 0:
		return 0
	hp += restored
	healed.emit(restored)
	health_changed.emit(hp, max_hp)
	return restored


## Brings a dead actor back with `amount` HP (a revive token).
func revive(amount: int) -> void:
	hp = clampi(amount, 1, max_hp)
	healed.emit(hp)
	health_changed.emit(hp, max_hp)


func set_shield(value: int) -> void:
	shield = maxi(value, 0)
	shield_changed.emit(shield)


func set_max_hp(value: int, refill: bool = false) -> void:
	max_hp = maxi(1, value)
	hp = max_hp if refill else mini(hp, max_hp)
	health_changed.emit(hp, max_hp)


func reset() -> void:
	hp = max_hp
	health_changed.emit(hp, max_hp)
