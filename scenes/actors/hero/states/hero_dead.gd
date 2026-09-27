extends State
## Out of HP. The room decides what happens next (EventBus.hero_died).


func enter(_msg: Dictionary = {}) -> void:
	var hero: Hero = actor
	hero.velocity = Vector2.ZERO
	hero.hitbox.deactivate()
	hero.hurtbox.set_deferred(&"monitorable", false)
	var tween: Tween = hero.create_tween()
	tween.tween_property(hero.visual, "scale", Vector2(1.4, 0.3), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(hero.visual, "self_modulate", Color(0.5, 0.3, 0.3), 0.35)


func physics_update(_delta: float) -> void:
	var hero: Hero = actor
	hero.velocity = Vector2.ZERO
	# Knockback from the killing blow still slides the body.
	hero.apply_movement()
