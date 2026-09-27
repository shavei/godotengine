class_name ThornPatch
extends Node2D
## Thorns left by a missed arrow (or a Spore Witch's cloud): hurts a hero standing in it
## every `interval` seconds, then withers. Makes the room smaller the longer its maker lives.

const FADE_TIME: float = 0.4
const SPIKES: int = 7

var attack: AttackData
var lifetime: float = 4.0
var interval: float = 0.8
## Fill color; the spikes are a lighter shade (thorns green, spore clouds yellow).
var color: Color = Color(0.28, 0.4, 0.16, 0.6)

var _time: float = 0.0
var _next_hit: float = 0.0

@onready var hitbox: HitboxComponent = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape


## Call before or right after adding to the tree.
func setup(hazard: AttackData, life: float, hit_interval: float, stats: CombatStats) -> void:
	attack = hazard
	lifetime = life
	interval = maxf(hit_interval, 0.05)
	if is_node_ready():
		_apply(stats)
	else:
		ready.connect(_apply.bind(stats), CONNECT_ONE_SHOT)


func _apply(stats: CombatStats) -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = attack.radius
	hitbox_shape.shape = shape
	hitbox.stats = stats
	queue_redraw()


func _physics_process(delta: float) -> void:
	if attack == null:
		return
	_time += delta
	if _time >= lifetime:
		hitbox.deactivate()
		set_physics_process(false)
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		tween.tween_callback(queue_free)
		return
	if _time >= _next_hit:
		# Re-arming lets the same hero be hit again once per interval.
		hitbox.activate(attack)
		_next_hit = _time + interval


func _draw() -> void:
	if attack == null:
		return
	var r: float = attack.radius
	draw_circle(Vector2.ZERO, r, color)
	for i: int in SPIKES:
		var angle: float = TAU * i / SPIKES
		var base: Vector2 = Vector2.RIGHT.rotated(angle) * r * 0.45
		var tip: Vector2 = Vector2.RIGHT.rotated(angle + 0.3) * r * 0.95
		draw_line(base, tip, Color(color.lightened(0.55), 1.0), 1.0)
