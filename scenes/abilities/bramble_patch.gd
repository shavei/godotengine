class_name BramblePatch
extends Node2D
## Bramble's vine patch: every `area_interval` it roots the enemies standing in it (the
## power's attack status; damage only if the attack has any), and it heals its hero
## `heal_per_second` while they stand inside. Withers after `area_duration`.

const SCENE_PATH: String = "res://scenes/abilities/bramble_patch.tscn"
const FADE_TIME: float = 0.4
const VINES: int = 9

var hero: Hero
var power: PowerData
var attack: AttackData

var _time: float = 0.0
var _next_pulse: float = 0.0
var _heal_owed: float = 0.0

@onready var area: Area2D = $Area
@onready var area_shape: CollisionShape2D = $Area/Shape


## Grows a patch of `power` at `owner_hero`'s feet.
static func grow(owner_hero: Hero, power_data: PowerData, patch_attack: AttackData) -> BramblePatch:
	var patch: BramblePatch = (load(SCENE_PATH) as PackedScene).instantiate()
	patch.hero = owner_hero
	patch.power = power_data
	patch.attack = patch_attack
	owner_hero.get_parent().add_child(patch)
	patch.global_position = owner_hero.global_position
	patch.reset_physics_interpolation()
	return patch


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = power.area_radius
	area_shape.shape = shape


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= power.area_duration:
		set_physics_process(false)
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		tween.tween_callback(queue_free)
		return
	if _time >= _next_pulse:
		_next_pulse = _time + maxf(power.area_interval, 0.05)
		_pulse()
	_heal_hero(delta)


## True if `world_position` is inside the patch.
func contains(world_position: Vector2) -> bool:
	return global_position.distance_to(world_position) <= power.area_radius


func _pulse() -> void:
	for other: Area2D in area.get_overlapping_areas():
		var hurtbox: HurtboxComponent = other as HurtboxComponent
		if hurtbox != null:
			hurtbox.receive_status(attack.status, attack.status_stacks, attack.stagger)


func _heal_hero(delta: float) -> void:
	if not is_instance_valid(hero) or hero.health.is_dead() or not contains(hero.global_position):
		return
	_heal_owed += power.heal_per_second * delta
	if _heal_owed >= 1.0:
		var amount: int = floori(_heal_owed)
		_heal_owed -= amount
		hero.health.heal(amount)


func _draw() -> void:
	var r: float = power.area_radius
	draw_circle(Vector2.ZERO, r, Color(power.color, 0.18))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(power.color, 0.6), 1.0)
	for i: int in VINES:
		var angle: float = TAU * i / VINES
		var from: Vector2 = Vector2.RIGHT.rotated(angle) * r * 0.2
		var mid: Vector2 = Vector2.RIGHT.rotated(angle + 0.35) * r * 0.6
		var tip: Vector2 = Vector2.RIGHT.rotated(angle + 0.1) * r * 0.9
		draw_polyline(PackedVector2Array([from, mid, tip]), power.color.darkened(0.2), 1.0)
