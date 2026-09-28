class_name VillagerData
extends Resource
## A villager job (docs/CONTENT.md Section 2): who they are, their workplace, the service
## they give with no power, and when they arrive. What a gift changes is in ComboData.

@export var id: StringName
## The villager's name ("Brann").
@export var display_name: String
## The job ("Smith").
@export var job_name: String
## The workplace ("Forge"). Becomes a BuildingData with levels in M6.
@export var workplace: String
## What the villager does with no power (an unpowered village still works).
@export var base_service: ServiceData
## Placeholder body color until villager sprites (M7).
@export var color: Color = Color.WHITE
## Renown level the villager moves in at (docs/GDD.md Section 5.5).
@export var arrives_at_renown: int = 1
## The house plot they take on arrival, if it is free.
@export var home_plot: int = 0
## What they say when you talk to them before any gift.
@export var greeting: String = ""


## "Brann the Smith".
func title() -> String:
	return "%s the %s" % [display_name, job_name]
