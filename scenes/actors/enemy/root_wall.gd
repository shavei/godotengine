class_name RootWall
extends StaticBody2D
## A Warden of Roots wall (docs/CONTENT.md Section 6.1). Shows its outline on the floor,
## bursts up (hurting anyone on it), then blocks heroes, enemies, arrows and seeds until
## it withers. It also withers when the boss that raised it dies.

enum Phase { WARNING, STANDING, WITHERING }

const WORLD_LAYER: int = 1
const FADE_TIME: float = 0.4
const SPIKE_GAP: float = 12.0

var phase: Phase = Phase.WARNING
var burst: AttackData
var length: float = 128.0
var thickness: float = 14.0
var life: float = 5.0
var color: Color = Color(0.4, 0.3, 0.18)

var _maker: Enemy = null
var _time: float = 0.0

@onready var shape: CollisionShape2D = $Shape
@onready var telegraph: TelegraphRing = $Telegraph
@onready var hitbox: HitboxComponent = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape


## Call right after adding to the tree. `along` is the wall's direction.
func setup(boss: BossData, along: Vector2, stats: CombatStats, maker: Enemy = null) -> void:
	burst = boss.root_wall
	length = boss.root_wall_length
	thickness = boss.root_wall_thickness
	life = boss.root_wall_life
	color = boss.root_wall_color
	_maker = maker
	rotation = along.angle() if along != Vector2.ZERO else 0.0
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(length, thickness)
	shape.shape = rect
	hitbox_shape.shape = rect
	hitbox.stats = stats
	telegraph.position = Vector2(-length * 0.5, 0.0)
	telegraph.play_line(Vector2.RIGHT, length, thickness, burst.windup)
	queue_redraw()


func is_solid() -> bool:
	return phase == Phase.STANDING


func _physics_process(delta: float) -> void:
	if burst == null or phase == Phase.WITHERING:
		return
	_time += delta
	if _maker != null and (not is_instance_valid(_maker) or _maker.is_dead()):
		wither()
		return
	match phase:
		Phase.WARNING:
			if _time >= burst.windup:
				phase = Phase.STANDING
				_time = 0.0
				shape.disabled = false
				hitbox.activate(burst)
				if burst.shake > 0.0:
					EventBus.camera_shake_requested.emit(burst.shake)
				queue_redraw()
		Phase.STANDING:
			if hitbox.active and _time >= burst.active:
				hitbox.deactivate()
			if _time >= life:
				wither()


func wither() -> void:
	if phase == Phase.WITHERING:
		return
	phase = Phase.WITHERING
	shape.set_deferred("disabled", true)
	hitbox.deactivate()
	telegraph.stop()
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(queue_free)


func _draw() -> void:
	if burst == null or phase == Phase.WARNING:
		return
	var half: Vector2 = Vector2(length, thickness) * 0.5
	draw_rect(Rect2(-half - Vector2.ONE, half * 2.0 + Vector2(2, 2)), Color(0.05, 0.03, 0.05))
	draw_rect(Rect2(-half, half * 2.0), color)
	var light: Color = color.lightened(0.35)
	var x: float = -half.x + SPIKE_GAP * 0.5
	while x < half.x:
		draw_line(Vector2(x - 3.0, half.y - 2.0), Vector2(x + 2.0, -half.y + 2.0), light, 1.0)
		x += SPIKE_GAP
