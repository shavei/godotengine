class_name EventChoiceData
extends Resource
## One answer to an Event room's question (docs/GDD.md Section 6.2: a short choice,
## risk for reward). EventResolver applies it.

@export var label: String
## Paid up front: currency -> amount. The choice is greyed out if the hero is short.
@export var cost: Dictionary[StringName, int] = {}
## Share of max HP lost up front. Never kills: the hero keeps at least 1 HP.
@export_range(0.0, 1.0) var hp_cost_fraction: float = 0.0
## Chance the reward comes after paying (1 = always).
@export_range(0.0, 1.0) var success_chance: float = 1.0
## Rolled on success.
@export var reward: DropTable
## Share of max HP healed on success.
@export_range(0.0, 1.0) var heal_fraction: float = 0.0
@export_multiline var success_text: String
@export_multiline var fail_text: String
