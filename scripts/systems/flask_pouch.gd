class_name FlaskPouch
extends RefCounted
## Healing flasks (docs/GDD.md Section 6.3): a few charges per run, each heals a share of max HP.

signal changed(charges: int, max_charges: int)

var max_charges: int
var charges: int
var heal_fraction: float


func _init(max_value: int = 3, heal: float = 0.35) -> void:
	max_charges = max_value
	charges = max_value
	heal_fraction = heal


## A flask cannot be wasted at full health or with no charges left.
func can_drink(hp: int, max_hp: int) -> bool:
	return charges > 0 and hp < max_hp and hp > 0


func heal_amount(max_hp: int) -> int:
	return roundi(max_hp * heal_fraction)


## Uses a charge and returns the HP to heal, or 0 if drinking is not allowed.
func drink(hp: int, max_hp: int) -> int:
	if not can_drink(hp, max_hp):
		return 0
	charges -= 1
	changed.emit(charges, max_charges)
	return heal_amount(max_hp)


func refill(amount: int = -1) -> void:
	charges = max_charges if amount < 0 else mini(max_charges, charges + amount)
	changed.emit(charges, max_charges)
