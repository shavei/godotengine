class_name AttackData
extends Resource
## One attack: a sword swing, a boar charge hit, an arrow. Timings are in seconds.

@export var damage: float = 10.0
## Wind-up before the hitbox turns on. Enemies use this as the telegraph.
@export var windup: float = 0.08
## How long the hitbox is live.
@export var active: float = 0.1
## Lock after the hitbox turns off.
@export var recovery: float = 0.2
## Distance from the attacker's center to the hitbox center, in pixels.
@export var reach: float = 20.0
## Hitbox radius in pixels.
@export var radius: float = 16.0
## Forward speed during wind-up and active time (px/s), gives swings weight.
@export var lunge_speed: float = 0.0
## Push applied to the target (px/s).
@export var knockback: float = 100.0
## Freeze frames on hit (s). 0 for light hits.
@export var hit_stop: float = 0.0
## Camera shake trauma added on hit (0 to 1).
@export var shake: float = 0.0

@export_group("Slash")
## Which way a melee slash sweeps: 1 clockwise, -1 the other way, 0 all at once. Steps of
## a combo alternate so each swing reads as its own.
@export var slash_sweep: float = 1.0
## Half the slash's angle in radians (1.2 is about 140 degrees in all).
@export var slash_arc: float = 1.2

@export_group("Status")
## Status this hit applies (&"burn", &"chill", &"root"; see StatusEffects). Empty for none.
@export var status: StringName = &""
## Stacks added per hit.
@export var status_stacks: int = 1
## Fills the target's stagger bar by this much (docs/GDD.md Section 7.3).
@export var stagger: float = 0.0
