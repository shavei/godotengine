class_name PowerBurst
extends Node2D
## A ring-shaped hit around a point (Bulwark's burst): the hitbox is live for a moment
## while a ring grows and fades.

const SCENE_PATH: String = "res://scenes/abilities/power_burst.tscn"
## Seconds the hitbox is live, and the whole ring animation.
const ACTIVE_TIME: float = 0.12
const FADE_TIME: float = 0.35

var radius: float = 32.0
var color: Color = Color.WHITE

var _time: float = 0.0

@onready var hitbox: HitboxComponent = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape


## Bursts at `world_position` with `attack` (its radius is the ring's size).
static func spawn(parent: Node, world_position: Vector2, attack: AttackData, stats: CombatStats, ring_color: Color) -> PowerBurst:
	var burst: PowerBurst = (load(SCENE_PATH) as PackedScene).instantiate()
	burst.radius = attack.radius
	burst.color = ring_color
	parent.add_child(burst)
	burst.global_position = world_position
	burst.reset_physics_interpolation()
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = attack.radius
	burst.hitbox_shape.shape = shape
	burst.hitbox.stats = stats
	burst.hitbox.activate(attack)
	if attack.shake > 0.0:
		EventBus.camera_shake_requested.emit(attack.shake)
	return burst


func _physics_process(delta: float) -> void:
	_time += delta
	if _time >= ACTIVE_TIME:
		hitbox.deactivate()
	if _time >= FADE_TIME:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var t: float = clampf(_time / FADE_TIME, 0.0, 1.0)
	var faded: Color = Color(color, 1.0 - t)
	draw_arc(Vector2.ZERO, radius * (0.6 + 0.4 * t), 0.0, TAU, 32, faded, 3.0)
	draw_circle(Vector2.ZERO, radius * (0.6 + 0.4 * t), Color(color, 0.25 * (1.0 - t)))
