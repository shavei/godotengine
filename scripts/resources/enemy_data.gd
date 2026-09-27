class_name EnemyData
extends Resource
## One enemy type (docs/CONTENT.md Section 6). Every enemy uses scenes/actors/enemy/enemy.tscn;
## `ai_script` picks the behavior, so a new enemy of an existing archetype needs no code.

@export var id: StringName
@export var display_name: String
## Informational: Swarm, Charger, Ranged, ... (docs/GDD.md Section 7.4).
@export var archetype: StringName
## An EnemyAI script (scripts/ai/).
@export var ai_script: Script

@export_group("Body")
@export var max_hp: int = 20
## Fraction of damage blocked (capped by CombatMath.ARMOR_CAP).
@export var armor: float = 0.0
@export var move_speed: float = 60.0
@export var body_radius: float = 6.0
## Multiplier on knockback taken. Heavy enemies use less than 1.
@export var weight_scale: float = 1.0
## Seconds a hit interrupts the enemy. 0 means hits never interrupt it.
@export var hit_stun: float = 0.2
@export var color: Color = Color(0.5, 0.7, 0.4)

@export_group("Attack")
## The attack's windup is its telegraph (0.4 to 0.8 s, docs/GDD.md Section 7.4).
@export var attack: AttackData
## Starts an attack when the target is this close (px).
@export var attack_range: float = 24.0
## Wait after an attack's recovery before the next one.
@export var attack_cooldown: float = 0.8

@export_group("Split on death")
@export var split_into: EnemyData
@export var split_count: int = 0

@export_group("Charger")
@export var charge_speed: float = 240.0
## Stun after charging into a wall (s).
@export var wall_stun: float = 1.5

@export_group("Ranged")
## Preferred distance from the target (px).
@export var keep_distance: float = 120.0
@export var projectile_speed: float = 180.0
@export var projectile_range: float = 220.0
## Hazard a missed projectile leaves behind (thorn patch). Null for none.
@export var hazard: AttackData
@export var hazard_lifetime: float = 4.0
## Seconds between hazard hits on the same target.
@export var hazard_interval: float = 0.8
