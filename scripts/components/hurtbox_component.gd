class_name HurtboxComponent
extends Area2D
## The area that can be hit. Turns an incoming hit into damage with CombatMath
## and applies it to the linked HealthComponent.

signal hurt(result: DamageResult, hitbox: HitboxComponent)

@export var health: HealthComponent
## While true, hits are ignored (dodge i-frames, post-hit grace).
@export var invincible: bool = false

var stats: CombatStats = CombatStats.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	monitoring = false
	monitorable = true
	rng.randomize()


func can_be_hit() -> bool:
	return not invincible and health != null and not health.is_dead()


## Called by a HitboxComponent. Returns the result, or null if the hit was ignored.
func receive_hit(hitbox: HitboxComponent) -> DamageResult:
	if not can_be_hit() or hitbox.attack == null:
		return null
	var result: DamageResult = CombatMath.damage(hitbox.attack.damage, hitbox.stats, stats, rng)
	health.take_damage(result.amount)
	hurt.emit(result, hitbox)
	return result
