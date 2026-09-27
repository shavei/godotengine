class_name CombatStats
extends RefCounted
## The numbers CombatMath needs from one side of a hit.
## Attackers use the offense fields, defenders the defense fields.
## ModifierStack (M4) will fill these from level, weapon, powers and village services.
## Defaults are neutral (no crits); the hero sets base crit from BalanceData.

# Offense
var weapon_tier: float = 1.0
## Sum of additive damage bonuses (Might, services, techniques). 0.15 means +15%.
var damage_bonus: float = 0.0
var crit_chance: float = 0.0
var crit_multiplier: float = 1.5

# Defense
## Fraction of damage blocked. Capped by CombatMath.ARMOR_CAP.
var armor: float = 0.0
## Status and other multipliers on damage taken (Radiant is 1.2).
var damage_taken_multiplier: float = 1.0
