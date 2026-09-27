class_name State
extends Node
## One state in a StateMachine. Override the hooks you need.

## The node that owns the StateMachine (the hero, an enemy). Set by the machine.
var actor: Node
var machine: StateMachine


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
