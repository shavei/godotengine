class_name BossData
extends EnemyData
## A mini-boss or region boss (docs/CONTENT.md Section 6). Same enemy scene as every
## other enemy; the boss AI plays `pattern` move by move (BossPattern) and reads the
## numbers for each move from here. A boss is never interrupted by hits (hit_stun 0)
## and gets a health bar with its name at the top of the screen.

@export_group("Pattern")
## Move names in order, repeated. Each boss AI knows its own moves.
@export var pattern: Array[StringName] = []
## Below this fraction of max HP the boss switches to `enraged_pattern` (0 = never).
@export_range(0.0, 1.0) var enrage_below: float = 0.0
@export var enraged_pattern: Array[StringName] = []
## Said on the banner when the boss enrages.
@export var enrage_line: String = ""

@export_group("Close")
## When the target is within `close_range` as a move starts, the boss uses this ring
## around its body instead (Warden: a root slam). Null for none.
@export var close_attack: AttackData
@export var close_range: float = 48.0

@export_group("Leap")
## A leap lands on the spot the target stood on and hits with `attack` there.
## Seconds in the air (the landing ring shows for the attack's windup plus this).
@export var leap_time: float = 0.5
@export var leap_height: float = 28.0

@export_group("Tongue")
## Shoots out along a telegraphed lane; a hit pulls the target toward the boss.
@export var tongue: AttackData
@export var tongue_range: float = 150.0
## Pull speed given to a target the tongue hits (px/s).
@export var tongue_pull: float = 520.0
## Seconds between moves after a tongue (a grab leads straight into the next move).
@export var tongue_cooldown: float = 0.3

@export_group("Volley")
## Fires `volley_count` projectiles (the enemy's `attack`) in a fan aimed at the target.
@export var volley_count: int = 5
@export var volley_spread_degrees: float = 50.0

@export_group("Root walls")
## Two walls burst up on either side of the target, along the line from the boss.
## The burst hurts (windup = the telegraph), then the walls block everyone, arrows and
## seeds included, for `root_wall_life` seconds.
@export var root_wall: AttackData
@export var root_wall_length: float = 128.0
@export var root_wall_thickness: float = 14.0
## Distance from the target to each wall's center line.
@export var root_wall_gap: float = 40.0
@export var root_wall_life: float = 5.0
@export var root_wall_color: Color = Color(0.4, 0.3, 0.18)
