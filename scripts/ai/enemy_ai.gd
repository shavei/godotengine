class_name EnemyAI
extends RefCounted
## Base enemy behavior. The Enemy creates one from EnemyData.ai_script and calls tick()
## every physics frame. Subclasses read numbers from `enemy.data`, never hardcode them.

var enemy: Enemy
## Counts down between attacks.
var cooldown: float = 0.0


func setup(owner_enemy: Enemy) -> void:
	enemy = owner_enemy


func tick(_delta: float) -> void:
	pass


## False while the enemy must not be stopped by a freeze or stun (a toad mid-leap).
func can_be_held() -> bool:
	return true


## A hit, a freeze or a stun stopped the enemy: cancel whatever it was doing.
func interrupt() -> void:
	enemy.cancel_attack()
