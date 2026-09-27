class_name EventData
extends Resource
## An Event room (docs/GDD.md Section 6.2): a short scene and 2 to 3 choices. The last
## choice should always be a free way out.

@export var id: StringName
@export var title: String
@export_multiline var text: String
@export var choices: Array[EventChoiceData] = []
