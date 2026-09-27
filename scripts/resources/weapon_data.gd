class_name WeaponData
extends Resource
## A weapon type (docs/CONTENT.md Section 5). Combo steps play in order.

@export var id: StringName
@export var display_name: String
## Weapon tier multiplier (Iron 1.0, Steel 1.3, Runed 1.7, Mythic 2.2).
@export var tier_multiplier: float = 1.0
@export var combo: Array[AttackData] = []
## Time into a step's recovery after which a buffered attack starts the next step.
@export var chain_after: float = 0.06
