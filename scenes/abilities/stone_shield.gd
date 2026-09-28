class_name StoneShield
extends Node2D
## Bulwark's shield around the hero: soaks up `shield_amount` damage (HealthComponent
## shield) for `area_duration` seconds, then bursts with the power's attack when it
## breaks or runs out. Drawn as a stone ring that thins as it takes damage.

var hero: Hero
var power: PowerData
var attack: AttackData

var _time: float = 0.0
var _done: bool = false


## Raises a shield on `hero` (replacing one that is already up).
static func raise(owner_hero: Hero, power_data: PowerData, burst_attack: AttackData) -> StoneShield:
	for child: Node in owner_hero.get_children():
		if child is StoneShield:
			(child as StoneShield).queue_free()
	var shield: StoneShield = StoneShield.new()
	shield.hero = owner_hero
	shield.power = power_data
	shield.attack = burst_attack
	shield.z_index = 2
	owner_hero.add_child(shield)
	return shield


func _ready() -> void:
	hero.health.set_shield(power.shield_amount)
	hero.health.shield_changed.connect(_on_shield_changed)


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= power.area_duration or hero.health.is_dead():
		_burst()
	queue_redraw()


func _on_shield_changed(shield: int) -> void:
	if shield <= 0:
		_burst.call_deferred()


func _burst() -> void:
	if _done:
		return
	_done = true
	hero.health.shield_changed.disconnect(_on_shield_changed)
	hero.health.set_shield(0)
	if not hero.health.is_dead():
		PowerBurst.spawn(hero.get_parent(), hero.global_position, attack, hero.power_stats, power.color)
	queue_free()


func _draw() -> void:
	var left: float = float(hero.health.shield) / maxf(power.shield_amount, 1.0)
	var points: PackedVector2Array = []
	for i: int in 7:
		points.append(Vector2.RIGHT.rotated(TAU * i / 6.0) * 12.0)
	draw_polyline(points, Color(power.color.lightened(0.3), 0.5 + 0.5 * left), 1.0 + 2.0 * left)
