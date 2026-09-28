class_name ComboData
extends Resource
## One villager+power pair (docs/CONTENT.md Section 3): the service a villager gives once
## they hold the power (Novice, then Adept) and the Technique a Master teaches.
## The id is "<villager>_<power>" (see id_for). The Technique is text until TechniqueData
## arrives with training in M5.

@export var id: StringName
@export var villager_id: StringName
@export var power_id: StringName
@export var novice: ServiceData
## What reaching Adept adds.
@export var adept: ServiceData
@export var technique_name: String = ""
@export_multiline var technique_text: String = ""
## What the villager says when they receive the power.
@export var gift_line: String = ""


static func id_for(villager: StringName, power: StringName) -> StringName:
	return StringName("%s_%s" % [villager, power])
