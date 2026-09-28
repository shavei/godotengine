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
## Move speed multiplier while swinging (the hero steers on top of the swing's lunge).
@export var attack_move_scale: float = 0.6

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
## Stick attacks turn toward a target this many degrees either side of the aim (0 = off).
@export var aim_assist_angle: float = 30.0
## Aim assist only looks this far (px).
@export var aim_assist_range: float = 64.0
## Controller rumble strength multiplier (0 = off).
@export var rumble_strength: float = 1.0

@export_group("Flasks")
@export var flask_charges: int = 3
@export var flask_heal_fraction: float = 0.35
@export var flask_drink_time: float = 0.4
## Move speed multiplier while drinking.
@export var flask_move_scale: float = 0.4

@export_group("Run rooms")
## A Rest room heals this share of max HP, or refills flasks (docs/GDD.md Section 6.2).
@export var rest_heal_fraction: float = 0.3
@export var rest_flask_refill: int = 1

@export_group("Merchant")
## A basic Merchant room's wares, in coins (docs/GDD.md Section 15.6). Each sells once.
@export var merchant_flask_price: int = 30
@export var merchant_heal_price: int = 25
@export var merchant_heal_fraction: float = 0.25
@export var merchant_shard_price: int = 60

@export_group("Progression")
## XP to go from level n-1 to level n: round(xp_curve_base * n ^ xp_curve_exponent) (docs/GDD.md Section 4.1).
@export var xp_curve_base: float = 50.0
@export var xp_curve_exponent: float = 1.5
@export var level_cap: int = 30
## Each level above 1 adds this much max HP (and one attribute point).
@export var level_max_hp: int = 4
## XP for clearing a room of each fight type.
@export var xp_combat_room: int = 15
@export var xp_elite_room: int = 60
@export var xp_mini_boss: int = 100
@export var xp_region_boss: int = 200
@export var attribute_cap: int = 20
## Might: weapon damage per point (0.03 = +3%).
@export var might_damage: float = 0.03
## Vigor: max HP and max stamina per point.
@export var vigor_max_hp: int = 10
@export var vigor_max_stamina: float = 5.0
## Focus: power damage and cooldown per point (powers arrive in M3).
@export var focus_power_damage: float = 0.03
@export var focus_cooldown: float = 0.015
## Weapon mastery: 1 mastery XP per this much damage dealt; level n (2 to cap) needs
## round(mastery_curve_base * n ^ mastery_curve_exponent) total mastery XP.
@export var mastery_damage_per_xp: int = 10
@export var mastery_curve_base: float = 150.0
@export var mastery_curve_exponent: float = 1.4
@export var mastery_cap: int = 10

@export_group("Run end")
## Share of coins and materials a hero keeps when they fall (docs/GDD.md Section 6.4).
@export var death_keep_fraction: float = 0.5
