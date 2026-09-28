class_name HurtboxComponent
extends Area2D
## The area that can be hit. Turns an incoming hit into damage with CombatMath
## and applies it to the linked HealthComponent.

signal hurt(result: DamageResult, hitbox: HitboxComponent)
## An attack touched this hurtbox while it was invincible (a dodge's i-frames). Emitted
## every frame the attack overlaps, so listeners keep their own once-per-dodge rule.
signal dodged(hitbox: HitboxComponent)

@export var health: HealthComponent
## While true, hits are ignored (dodge i-frames, post-hit grace).
@export var invincible: bool = false
## Receives the statuses and stagger hits carry. Left empty, hits apply none.
@export var status: StatusComponent

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
	if hitbox.attack == null:
		return null
	if not can_be_hit():
		if invincible and health != null and not health.is_dead():
			dodged.emit(hitbox)
		return null
	var result: DamageResult = CombatMath.damage(hitbox.attack.damage, hitbox.stats, stats, rng)
	health.take_damage(result.amount)
	hurt.emit(result, hitbox)
	if not health.is_dead():
		receive_status(hitbox.attack.status, hitbox.attack.status_stacks, hitbox.attack.stagger)
	return result


## Applies a status and stagger without damage (a Bramble patch rooting what stands in it).
func receive_status(id: StringName, stacks: int = 1, stagger: float = 0.0) -> void:
	if status == null or not can_be_hit():
		return
	if id != &"":
		status.apply(id, stacks)
	if stagger > 0.0:
		status.add_stagger(stagger)
