class_name ThornArrow
extends Area2D
## A Thorn Archer's arrow (or a Warden's seed). Flies straight; if it misses the hero it
## drops the shooter's hazard, if any, where it stops (a wall or its max range), per
## docs/CONTENT.md Section 6.1. A level 5 Bulwark shield can reflect it back at enemies.

const PATCH_SCENE: PackedScene = preload("res://scenes/actors/enemy/thorn_patch.tscn")
## Enemy projectiles a shield can reflect are in this group.
const GROUP: StringName = &"enemy_projectiles"
## Hitbox layers after a reflect: a hero hitbox (layer 4) that hits enemy hurtboxes (layer 7).
const HERO_HITBOX_LAYER: int = 8
const ENEMY_HURTBOX_MASK: int = 64

var direction: Vector2 = Vector2.RIGHT
var data: EnemyData

var _traveled: float = 0.0
var _done: bool = false
## Turned back by a shield: it now hits enemies and leaves no hazard.
var _reflected: bool = false

@onready var hitbox: HitboxComponent = $Hitbox
@onready var hitbox_shape: CollisionShape2D = $Hitbox/Shape
@onready var visual: PlaceholderShape = $Visual


func _ready() -> void:
	add_to_group(GROUP)
	body_entered.connect(_on_body_entered)
	hitbox.hit_landed.connect(_on_hit_landed)


func launch(dir: Vector2, enemy_data: EnemyData, stats: CombatStats) -> void:
	direction = dir.normalized()
	data = enemy_data
	rotation = direction.angle()
	visual.size = data.projectile_size
	visual.color = data.projectile_color
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = data.attack.radius
	hitbox_shape.shape = shape
	hitbox.stats = stats
	hitbox.activate(data.attack)


## Sends the arrow back the way it came as the hero's hit (`stats` are the hero's power
## stats), with its full range again.
func reflect(stats: CombatStats) -> void:
	if _done or _reflected:
		return
	_reflected = true
	remove_from_group(GROUP)
	direction = -direction
	rotation = direction.angle()
	_traveled = 0.0
	hitbox.collision_layer = HERO_HITBOX_LAYER
	hitbox.collision_mask = ENEMY_HURTBOX_MASK
	hitbox.stats = stats
	hitbox.activate(hitbox.attack)


func is_reflected() -> bool:
	return _reflected


func _physics_process(delta: float) -> void:
	if _done or data == null:
		return
	var step: float = data.projectile_speed * delta
	position += direction * step
	_traveled += step
	if _traveled >= data.projectile_range:
		_land(global_position)


func _on_body_entered(_body: Node2D) -> void:
	# Stop just short of the wall so the patch sits on the floor.
	_land(global_position - direction * 6.0)


func _on_hit_landed(_hurtbox: HurtboxComponent, _result: DamageResult) -> void:
	_done = true
	queue_free()


func _land(at: Vector2) -> void:
	if _done:
		return
	_done = true
	hitbox.deactivate()
	if data.hazard != null and not _reflected:
		var patch: ThornPatch = PATCH_SCENE.instantiate()
		patch.color = data.hazard_color
		get_parent().add_child.call_deferred(patch)
		patch.position = get_parent().to_local(at)
		patch.setup(data.hazard, data.hazard_lifetime, data.hazard_interval, hitbox.stats)
	queue_free()
