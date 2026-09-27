class_name WaveTracker
extends RefCounted
## Room clear rules: a wave is cleared when every enemy it spawned (splits included)
## is dead; the room is cleared when the last wave is. Enemies count as alive from the
## moment their spawn is scheduled, so a spawn warning never lets a wave end early.

enum Event { NONE, WAVE_CLEARED, ROOM_CLEARED }

var wave_count: int = 0
## -1 before the first wave.
var current_wave: int = -1
var alive: int = 0


func _init(waves: int) -> void:
	wave_count = maxi(0, waves)


func has_next_wave() -> bool:
	return current_wave + 1 < wave_count


## Moves to the next wave and returns its index, or -1 if there is none.
func start_next_wave() -> int:
	if not has_next_wave():
		return -1
	current_wave += 1
	return current_wave


func add_alive(count: int = 1) -> void:
	alive += maxi(0, count)


## Call once per enemy death. Spawn any split children with add_alive() first.
func remove_alive() -> Event:
	if alive <= 0:
		return Event.NONE
	alive -= 1
	if alive > 0:
		return Event.NONE
	return Event.WAVE_CLEARED if has_next_wave() else Event.ROOM_CLEARED


func is_room_cleared() -> bool:
	return wave_count == 0 or (current_wave == wave_count - 1 and alive == 0)
