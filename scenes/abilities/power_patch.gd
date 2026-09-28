class_name PowerPatch
extends Node2D
## A lingering patch on the ground (Bramble's vines, Fire's burning ground). Every
## `pulse_interval` it gives the enemies standing in it `pulse_attack`'s status (no
## damage); every `damage_interval` its `damage_attack` hits them, if it has one. It heals
## its hero `heal_per_second` while they stand inside, can spread to `spread` times its
## radius over its life, and withers after `duration`.

const SCENE_PATH: String = "res://scenes/abilities/power_patch.tscn"
const FADE_TIME: float = 0.4
const VINES: int = 9

var hero: Hero
var color: Color = Color.WHITE
## Starting radius (px) and lifetime (s).
var radius: float = 32.0
var duration: float = 4.0
## Statuses (and stagger) given to enemies inside, every pulse_interval seconds.
var pulse_attack: AttackData
var pulse_interval: float = 1.0
## A hit on enemies inside every damage_interval seconds (null for none).
var damage_attack: AttackData
var damage_interval: float = 1.0
var heal_per_second: float = 0.0
## Radius at the end of the patch's life, as a multiple of `radius` (1 = no spread).
var spread: float = 1.0
## Draw vines (Bramble) instead of flames.
var vines: bool = true

var _time: float = 0.0
var _next_pulse: float = 0.0
var _next_damage: float = 0.0
var _heal_owed: float = 0.0
var _shape: CircleShape2D = CircleShape2D.new()
var _hit_shape: CircleShape2D = CircleShape2D.new()

@onready var area: Area2D = $Area
@onready var area_shape: CollisionShape2D = $Area/Shape
@onready var hitbox: HitboxComponent = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape


## A patch owned by `owner_hero` (not in the tree yet): set its numbers, then place() it.
static func make(owner_hero: Hero, patch_color: Color) -> PowerPatch:
	var patch: PowerPatch = (load(SCENE_PATH) as PackedScene).instantiate()
	patch.hero = owner_hero
	patch.color = patch_color
	return patch


## Adds the patch next to its hero at `world_position`.
func place(world_position: Vector2) -> void:
	hero.get_parent().add_child(self)
	global_position = world_position
	reset_physics_interpolation()


func _ready() -> void:
	area_shape.shape = _shape
	hitbox_shape.shape = _hit_shape
	_set_radius(radius)
	if is_instance_valid(hero):
		hitbox.stats = hero.power_stats


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= duration:
		set_physics_process(false)
		hitbox.deactivate()
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		tween.tween_callback(queue_free)
		return
	if spread > 1.0:
		_set_radius(radius * lerpf(1.0, spread, _time / maxf(duration, 0.01)))
	if pulse_attack != null and _time >= _next_pulse:
		_next_pulse = _time + maxf(pulse_interval, 0.05)
		_pulse()
	if damage_attack != null and _time >= _next_damage:
		_next_damage = _time + maxf(damage_interval, 0.05)
		# A fresh activation lets the hitbox hit every enemy inside once more.
		hitbox.activate(damage_attack)
	_heal_hero(delta)


## The patch's radius now (it grows if it spreads).
func current_radius() -> float:
	return _shape.radius


## True if `world_position` is inside the patch.
func contains(world_position: Vector2) -> bool:
	return global_position.distance_to(world_position) <= current_radius()


func _set_radius(value: float) -> void:
	_shape.radius = value
	_hit_shape.radius = value
	queue_redraw()


func _pulse() -> void:
	for other: Area2D in area.get_overlapping_areas():
		var hurtbox: HurtboxComponent = other as HurtboxComponent
		if hurtbox != null:
			hurtbox.receive_status(pulse_attack.status, pulse_attack.status_stacks, pulse_attack.stagger)


func _heal_hero(delta: float) -> void:
	if heal_per_second <= 0.0 or not is_instance_valid(hero) or hero.health.is_dead() or not contains(hero.global_position):
		return
	_heal_owed += heal_per_second * delta
	if _heal_owed >= 1.0:
		var amount: int = floori(_heal_owed)
		_heal_owed -= amount
		hero.health.heal(amount)


func _draw() -> void:
	var r: float = current_radius()
	draw_circle(Vector2.ZERO, r, Color(color, 0.18))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(color, 0.6), 1.0)
	for i: int in VINES:
		var angle: float = TAU * i / VINES
		if vines:
			var from: Vector2 = Vector2.RIGHT.rotated(angle) * r * 0.2
			var mid: Vector2 = Vector2.RIGHT.rotated(angle + 0.35) * r * 0.6
			var tip: Vector2 = Vector2.RIGHT.rotated(angle + 0.1) * r * 0.9
			draw_polyline(PackedVector2Array([from, mid, tip]), color.darkened(0.2), 1.0)
		else:
			# Little flames: a short upward tick at scattered points.
			var at: Vector2 = Vector2.RIGHT.rotated(angle * 2.3) * r * (0.25 + 0.6 * fmod(i * 0.37, 1.0))
			draw_line(at, at + Vector2(0, -3), color.lightened(0.3), 1.0)
