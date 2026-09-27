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


## A hit staggered the enemy: cancel whatever it was doing.
func interrupt() -> void:
	enemy.cancel_attack()
