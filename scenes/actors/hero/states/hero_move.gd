extends State
## Idle and running. Starts dodges, attacks and flasks.


func physics_update(delta: float) -> void:
	var hero: Hero = actor
	hero.update_facing()
	if hero.try_start_action():
		return
	hero.move_with_input(delta)
