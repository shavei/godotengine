extends TechniqueBehavior
## Ember Step (Master Smith with Fire): every dodge leaves a trail of small fire patches
## that Burn the enemies standing in them. A patch every BalanceData.ember_step_spacing px
## of the roll, the first where it starts.

const FIRE_COLOR: Color = Color(1, 0.5, 0.2)

var _last_drop: Vector2 = Vector2.ZERO


func _ready() -> void:
	hero.dodge_started.connect(_on_dodge_started)


func _physics_process(_delta: float) -> void:
	if not hero.state_machine.is_in(&"Dodge"):
		return
	if hero.global_position.distance_to(_last_drop) >= hero.balance.ember_step_spacing:
		drop()


## Leaves one fire patch where the hero stands. Returns it.
func drop() -> PowerPatch:
	var tuning: BalanceData = hero.balance
	var patch: PowerPatch = PowerPatch.make(hero, FIRE_COLOR)
	patch.radius = tuning.ember_step_radius
	patch.duration = tuning.ember_step_duration
	patch.vines = false
	var burn: AttackData = AttackData.new()
	burn.damage = tuning.ember_step_damage
	burn.status = StatusEffects.BURN
	patch.damage_attack = burn
	patch.damage_interval = tuning.ember_step_interval
	patch.place(hero.global_position)
	_last_drop = hero.global_position
	return patch


func _on_dodge_started() -> void:
	drop()
