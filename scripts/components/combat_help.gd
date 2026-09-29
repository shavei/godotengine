class_name CombatHelp
extends Node
## Keeps a room's help line (a Label, this node's parent) naming the inputs of the device
## the player is using: gamepad buttons while playing with a pad, keys with the keyboard.
## Both devices at once did not fit on one line.

## ["Label", action] pairs after Move, Aim, Attack, Dodge and Flask.
var extra: Array[Array] = []


## Adds a CombatHelp to `label` and fills it in now.
static func attach(label: Label, extra_pairs: Array[Array]) -> CombatHelp:
	var help: CombatHelp = CombatHelp.new()
	help.name = "CombatHelp"
	help.extra = extra_pairs
	label.add_child(help)
	help.refresh()
	return help


func _ready() -> void:
	EventBus.input_device_changed.connect(func(_kind: int) -> void: refresh())


func refresh() -> void:
	var label: Label = get_parent() as Label
	if label != null:
		label.text = InputBindings.combat_help(extra, InputBindings.active_kind)
