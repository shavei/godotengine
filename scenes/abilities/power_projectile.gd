class_name PowerProjectile
extends Area2D
## A power's bolt or shard (Ember Bolt, Frost Shard). Flies straight from the hero, hits
## the first enemy it touches, and stops at walls or its range.

## Hit an enemy (later levels explode or pierce from here).
signal hit(hurtbox: HurtboxComponent, result: DamageResult)
## Stopped at a wall or its range, at this world position.
signal landed(at: Vector2)

const SCENE_PATH: String = "res://scenes/abilities/power_projectile.tscn"

var direction: Vector2 = Vector2.RIGHT
var power: PowerData
## Keeps flying after a hit.
var pierce: bool = false

var _traveled: float = 0.0
var _done: bool = false

@onready var hitbox: HitboxComponent = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape
@onready var visual: PlaceholderShape = $Visual


## Spawns a projectile of `power` next to `hero`, flying along `dir`.
static func fire(hero: Hero, dir: Vector2, power_data: PowerData, attack: AttackData) -> PowerProjectile:
	var shot: PowerProjectile = (load(SCENE_PATH) as PackedScene).instantiate()
	hero.get_parent().add_child(shot)
	shot.global_position = hero.global_position + dir.normalized() * 8.0
	shot.reset_physics_interpolation()
	shot.launch(dir, power_data, attack, hero.power_stats)
	return shot


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	hitbox.hit_landed.connect(_on_hit_landed)


func launch(dir: Vector2, power_data: PowerData, attack: AttackData, stats: CombatStats) -> void:
	direction = dir.normalized()
	power = power_data
	rotation = direction.angle()
	visual.size = power.projectile_size
	visual.shape = PlaceholderShape.Shape.CIRCLE if is_equal_approx(power.projectile_size.x, power.projectile_size.y) else PlaceholderShape.Shape.RECT
	visual.color = power.color
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = attack.radius
	hitbox_shape.shape = shape
	hitbox.stats = stats
	hitbox.activate(attack)


func _physics_process(delta: float) -> void:
	if _done or power == null:
		return
	var step: float = power.projectile_speed * delta
	position += direction * step
	_traveled += step
	if _traveled >= power.projectile_range:
		_finish(global_position)


func _on_body_entered(_body: Node2D) -> void:
	_finish(global_position - direction * 4.0)


func _on_hit_landed(hurtbox: HurtboxComponent, result: DamageResult) -> void:
	EventBus.camera_shake_requested.emit(hitbox.attack.shake)
	hit.emit(hurtbox, result)
	if not pierce:
		_done = true
		hitbox.deactivate()
		queue_free()


func _finish(at: Vector2) -> void:
	if _done:
		return
	_done = true
	hitbox.deactivate()
	landed.emit(at)
	queue_free()
