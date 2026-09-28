class_name PowerData
extends Resource
## One power (docs/CONTENT.md Section 1). A kept power is an active ability on its own
## button; `ability_script` (an Ability in scripts/abilities/) decides what a cast does
## and reads every number from here, so tuning a power needs no code.

@export var id: StringName
@export var display_name: String
## The ability's name (Ember Bolt, Frost Shard, ...).
@export var ability_name: String
@export_multiline var description: String
@export var color: Color = Color.WHITE
## Placeholder icon drawn by PowerIcon: flame, snowflake, bolt, square, leaf, swirl, sun, crescent.
@export var icon_shape: StringName = &""
## An Ability script (scripts/abilities/).
@export var ability_script: Script
## Seconds between casts before Focus (docs/GDD.md Section 4.3: 4 to 8).
@export var base_cooldown: float = 5.0
## The ability's hit: damage at level 1, size, push, and the status it applies.
@export var attack: AttackData
@export var level3_text: String
@export var level5_text: String

@export_group("Projectile")
## Bolts and shards: how many per cast, the fan they spread over, speed and range.
@export var projectile_count: int = 1
@export var spread_degrees: float = 0.0
@export var projectile_speed: float = 240.0
@export var projectile_range: float = 200.0
@export var projectile_size: Vector2 = Vector2(8, 8)

@export_group("Area")
## Patches, shields and bursts: radius (px), how long they last (s) and how often a
## lingering area pulses (s).
@export var area_radius: float = 32.0
@export var area_duration: float = 4.0
@export var area_interval: float = 1.0
## Stone: damage the shield soaks up before it bursts.
@export var shield_amount: int = 0
## Growth: HP per second healed while standing in the patch.
@export var heal_per_second: float = 0.0
