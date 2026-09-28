extends TechniqueBehavior
## Cold Temper (Master Smith with Frost): a perfect dodge, rolling through an attack,
## Chills every enemy within BalanceData.cold_temper_radius, with a frosty ring to show it.

const FROST_COLOR: Color = Color(0.6, 0.85, 1)


func _ready() -> void:
	hero.perfect_dodge.connect(_on_perfect_dodge)


## Chills the enemies close to the hero. Returns how many.
func chill_nearby() -> int:
	var radius: float = hero.balance.cold_temper_radius
	var chilled: int = 0
	for node: Node in hero.get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.global_position.distance_to(hero.global_position) > radius:
			continue
		enemy.hurtbox.receive_status(StatusEffects.CHILL, hero.balance.cold_temper_stacks)
		chilled += 1
	# The ring only shows the reach; its hitbox never hits.
	var ring: AttackData = AttackData.new()
	ring.radius = radius
	var burst: PowerBurst = PowerBurst.spawn(world(), hero.global_position, ring, hero.power_stats, FROST_COLOR)
	burst.hitbox.deactivate()
	DamageNumber.spawn(world(), hero.global_position + Vector2(0, -20), "Perfect!", FROST_COLOR)
	return chilled


func _on_perfect_dodge(_source: HitboxComponent) -> void:
	chill_nearby()
