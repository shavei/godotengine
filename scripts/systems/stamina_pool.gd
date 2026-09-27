class_name StaminaPool
extends RefCounted
## Stamina rules (docs/GDD.md Section 7.2): spending pauses regen for a short delay,
## then it refills at a fixed rate.

signal changed(current: float, maximum: float)

var maximum: float
var current: float
var regen_per_second: float
var regen_delay: float

var _delay_left: float = 0.0


func _init(max_value: float = 100.0, regen: float = 40.0, delay: float = 0.5) -> void:
	maximum = max_value
	current = max_value
	regen_per_second = regen
	regen_delay = delay


func can_spend(amount: float) -> bool:
	return current >= amount


## Spends `amount` if there is enough. Returns false (and spends nothing) otherwise.
func try_spend(amount: float) -> bool:
	if not can_spend(amount):
		return false
	current -= amount
	_delay_left = regen_delay
	changed.emit(current, maximum)
	return true


func tick(delta: float) -> void:
	if current >= maximum:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		if _delay_left > 0.0:
			return
		# Use the leftover part of this frame for regen.
		delta = -_delay_left
		_delay_left = 0.0
	current = minf(maximum, current + regen_per_second * delta)
	changed.emit(current, maximum)
