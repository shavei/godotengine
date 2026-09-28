extends TechniqueBehavior
## Cold Blood (Master Healer with Frost): the first time in a room the hero's HP drops
## below BalanceData.low_hp_fraction, time slows (cold_blood_time_scale for
## cold_blood_duration real seconds). The hero gets a new behavior in every room, so it
## works once a room.

const FROST_COLOR: Color = Color(0.6, 0.85, 1)

var used: bool = false
var _last_hp: int = 0


func _ready() -> void:
	_last_hp = hero.health.hp
	hero.health.health_changed.connect(_on_health_changed)


func _on_health_changed(current: int, maximum: int) -> void:
	var line: float = maximum * hero.balance.low_hp_fraction
	var crossed: bool = _last_hp >= line and current < line and current > 0
	_last_hp = current
	if used or not crossed:
		return
	used = true
	HitStop.slow(hero.get_tree(), hero.balance.cold_blood_time_scale, hero.balance.cold_blood_duration)
	DamageNumber.spawn(world(), hero.global_position + Vector2(0, -20), "Cold Blood", FROST_COLOR)
