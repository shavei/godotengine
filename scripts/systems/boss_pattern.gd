class_name BossPattern
extends RefCounted
## Which move a boss makes next (docs/GDD.md Section 15.5): its moves play in a fixed
## order and repeat; once its HP drops below the enrage line it switches, for good, to
## the enraged order from its first move.

var moves: Array[StringName] = []
var enraged_moves: Array[StringName] = []
## Fraction of max HP. 0 means the boss never enrages.
var enrage_below: float = 0.0
var enraged: bool = false

var _index: int = 0


func _init(normal: Array[StringName] = [], enraged_order: Array[StringName] = [], below: float = 0.0) -> void:
	moves = normal
	enraged_moves = enraged_order
	enrage_below = below


static func from_data(data: BossData) -> BossPattern:
	return BossPattern.new(data.pattern, data.enraged_pattern, data.enrage_below)


## True once, the first time `hp_fraction` is below the enrage line.
func check_enrage(hp_fraction: float) -> bool:
	if enraged or enrage_below <= 0.0 or enraged_moves.is_empty() or hp_fraction >= enrage_below:
		return false
	enraged = true
	_index = 0
	return true


## The next move for a boss at `hp_fraction` of its max HP (&"" with no moves).
func next(hp_fraction: float) -> StringName:
	check_enrage(hp_fraction)
	var order: Array[StringName] = enraged_moves if enraged else moves
	if order.is_empty():
		return &""
	var move: StringName = order[_index % order.size()]
	_index += 1
	return move
