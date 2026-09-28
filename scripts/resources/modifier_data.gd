class_name ModifierData
extends Resource
## One stat change from a service (later also Techniques, Neighbor bonuses, meals and
## trinkets). ModifierStack adds them up: every "add" is summed onto the base, then every
## "mul" multiplies the result. Targets are listed in ModifierStack.

const ADD: StringName = &"add"
const MUL: StringName = &"mul"

## What it changes, like &"run.flask_charges" (see the ModifierStack constants).
@export var target: StringName
@export var op: StringName = ADD
@export var value: float = 0.0
## Only counts when this condition holds (&"boss_room"); empty means always.
@export var condition: StringName = &""


static func create(target_id: StringName, amount: float, operation: StringName = ADD, when: StringName = &"") -> ModifierData:
	var modifier: ModifierData = ModifierData.new()
	modifier.target = target_id
	modifier.value = amount
	modifier.op = operation
	modifier.condition = when
	return modifier
