class_name StateMachine
extends Node
## Runs one child State at a time. States are found by node name (snake_case works best).
## The owner calls physics_update() from its own _physics_process so the order is explicit.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: State

var current: State
var _states: Dictionary = {}


## Call from the owner's _ready (after children are ready).
func start(actor: Node) -> void:
	for child: Node in get_children():
		var state: State = child as State
		if state == null:
			continue
		state.actor = actor
		state.machine = self
		_states[StringName(state.name)] = state
	current = initial_state
	if current == null and not _states.is_empty():
		current = _states.values()[0]
	if current != null:
		current.enter()


func physics_update(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	var next: State = _states.get(state_name, null)
	if next == null:
		push_error("StateMachine: no state named %s" % state_name)
		return
	var from: StringName = current.name if current != null else &""
	if current != null:
		current.exit()
	current = next
	current.enter(msg)
	state_changed.emit(from, state_name)


func is_in(state_name: StringName) -> bool:
	return current != null and current.name == state_name
