class_name PowerLoadout
extends RefCounted
## The powers a hero carries into a fight: one slot per Power button, each with a level
## and a cooldown. Pure logic; the hero ticks it and the HUD draws it.

## The powers or their levels changed (not emitted for cooldown ticks).
signal changed


class Slot:
	extends RefCounted
	var power: PowerData
	var level: int = 1
	## Seconds until the power can be cast again.
	var remaining: float = 0.0
	## Length of the last cooldown (for the HUD's fill).
	var duration: float = 0.0


## One entry per slot; null for an empty slot.
var slots: Array[Slot] = []


func _init(slot_count: int = 3) -> void:
	slots.resize(maxi(slot_count, 0))


## Fills the slots in order. Extra powers beyond the slot count are ignored.
func set_powers(powers: Array[PowerData], levels: Array[int] = []) -> void:
	for i: int in slots.size():
		slots[i] = null
		if i < powers.size() and powers[i] != null:
			var entry: Slot = Slot.new()
			entry.power = powers[i]
			entry.level = levels[i] if i < levels.size() else 1
			slots[i] = entry
	changed.emit()


func slot(index: int) -> Slot:
	return slots[index] if index >= 0 and index < slots.size() else null


func power_count() -> int:
	return slots.filter(func(entry: Slot) -> bool: return entry != null).size()


func is_ready(index: int) -> bool:
	var entry: Slot = slot(index)
	return entry != null and entry.remaining <= 0.0


func start_cooldown(index: int, seconds: float) -> void:
	var entry: Slot = slot(index)
	if entry == null:
		return
	entry.duration = maxf(seconds, 0.0)
	entry.remaining = entry.duration


## 1 right after a cast, 0 when ready.
func cooldown_fraction(index: int) -> float:
	var entry: Slot = slot(index)
	if entry == null or entry.duration <= 0.0:
		return 0.0
	return clampf(entry.remaining / entry.duration, 0.0, 1.0)


func tick(delta: float) -> void:
	for entry: Slot in slots:
		if entry != null and entry.remaining > 0.0:
			entry.remaining = maxf(entry.remaining - delta, 0.0)
