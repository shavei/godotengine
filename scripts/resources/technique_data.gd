class_name TechniqueData
extends Resource
## A permanent passive a Master villager teaches (docs/GDD.md Section 4.5): one per
## villager+power combo, always active, never takes a slot. Most are only modifiers
## (ModifierStack targets the hero reads); an effect that is more than numbers (a fire
## trail behind a dodge) also names a `behavior_script`, a TechniqueBehavior the hero
## carries in every run room.

@export var id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## What the Master says as they teach it (the lesson moment in the village).
@export var lesson_line: String = ""
@export var modifiers: Array[ModifierData] = []
## A TechniqueBehavior script, or null for a Technique that is only modifiers.
@export var behavior_script: Script
