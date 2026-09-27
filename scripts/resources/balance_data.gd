class_name BalanceData
extends Resource
## Every tunable number in one place (docs/ARCHITECTURE.md Section 4.1).
## Defaults match docs/GDD.md; data/balance/balance_default.tres is what the game loads.

@export var id: StringName = &"default"

@export_group("Hero")
@export var hero_max_hp: int = 100
@export var hero_max_stamina: float = 100.0
@export var hero_move_speed: float = 110.0
## px/s per second when speeding up.
@export var hero_acceleration: float = 1000.0
## px/s per second when slowing down with no input.
@export var hero_friction: float = 1400.0
@export var hero_crit_chance: float = 0.05
@export var hero_crit_multiplier: float = 1.5

@export_group("Dodge and stamina")
@export var dodge_duration: float = 0.3
@export var dodge_iframes: float = 0.22
@export var dodge_distance: float = 72.0
@export var dodge_stamina_cost: float = 25.0
@export var stamina_regen: float = 40.0
@export var stamina_regen_delay: float = 0.5

@export_group("Getting hit")
@export var hurt_stun: float = 0.2
@export var hurt_iframes: float = 0.6

@export_group("Input feel")
## A press this early before an action is allowed still counts.
@export var input_buffer: float = 0.15
## After a combo ends, pressing attack within this time continues it.
@export var combo_reset: float = 0.35

@export_group("Flasks")
@export var flask_charges: int = 3
@export var flask_heal_fraction: float = 0.35
@export var flask_drink_time: float = 0.4
## Move speed multiplier while drinking.
@export var flask_move_scale: float = 0.4
