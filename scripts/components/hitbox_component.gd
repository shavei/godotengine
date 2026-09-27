class_name HitboxComponent
extends Area2D
## The damaging area of an attack. While active it hits each overlapping hurtbox once.
## Call activate() at the start of every swing so the same target can be hit again.

signal hit_landed(hurtbox: HurtboxComponent, result: DamageResult)

var attack: AttackData
var stats: CombatStats = CombatStats.new()
var active: bool = false

var _already_hit: Array[HurtboxComponent] = []


func _ready() -> void:
	monitoring = true
	monitorable = false


func activate(new_attack: AttackData) -> void:
	attack = new_attack
	active = true
	_already_hit.clear()


func deactivate() -> void:
	active = false


func _physics_process(_delta: float) -> void:
	if active:
		check_hits()


func check_hits() -> void:
	for area: Area2D in get_overlapping_areas():
		var hurtbox: HurtboxComponent = area as HurtboxComponent
		if hurtbox == null or _already_hit.has(hurtbox):
			continue
		var result: DamageResult = hurtbox.receive_hit(self)
		if result != null:
			_already_hit.append(hurtbox)
			hit_landed.emit(hurtbox, result)
