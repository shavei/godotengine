class_name Hud
extends CanvasLayer
## Run HUD (docs/GDD.md Section 13): HP, stamina, flasks, power slots with cooldowns
## and, in runs, what the hero has picked up and a boss's health. Call bind_hero() once (and bind_wallet() in runs,
## bind_boss() when a boss appears); the HUD then follows their signals.

const DENIED_COLOR: Color = Color(1.0, 0.3, 0.3)
## Top-left corner of the power slot row (bottom-left, above the help line).
const POWER_ROW_POSITION: Vector2 = Vector2(8, 306)

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var flask_label: Label = %FlaskLabel
@onready var loot_label: RichTextLabel = %LootLabel
@onready var boss_panel: Control = %BossPanel
@onready var boss_name: Label = %BossName
@onready var boss_bar: ProgressBar = %BossBar

var _denied_tween: Tween
var _wallet: Wallet
var _currencies: Array[StringName] = []
var _power_row: HBoxContainer
var _power_views: Array[PowerSlotView] = []


func bind_hero(hero: Hero) -> void:
	hero.health.health_changed.connect(_on_health_changed)
	hero.stamina.changed.connect(_on_stamina_changed)
	hero.flasks.changed.connect(_on_flasks_changed)
	hero.dodge_denied.connect(_on_dodge_denied)
	_on_health_changed(hero.health.hp, hero.health.max_hp)
	_on_stamina_changed(hero.stamina.current, hero.stamina.maximum)
	_on_flasks_changed(hero.flasks.charges, hero.flasks.max_charges)
	_bind_powers(hero)


## Shows `currencies` from `wallet`, in that order (coins, region material, Crystal, shards).
func bind_wallet(wallet: Wallet, currencies: Array[StringName]) -> void:
	_wallet = wallet
	_currencies = currencies
	wallet.changed.connect(func(_currency: StringName, _amount: int) -> void: _refresh_loot())
	loot_label.show()
	_refresh_loot()


## Shows `boss`'s name and health at the top of the screen until it dies.
func bind_boss(boss: Enemy) -> void:
	boss_name.text = boss.data.display_name
	boss_bar.max_value = boss.health.max_hp
	boss_bar.value = boss.health.hp
	boss_panel.show()
	boss.health.health_changed.connect(_on_boss_health_changed)
	boss.died.connect(func(_enemy: Enemy) -> void: boss_panel.hide())


## One slot view per Power button. The row hides while the hero has no powers.
func _bind_powers(hero: Hero) -> void:
	_power_row = HBoxContainer.new()
	_power_row.name = "PowerRow"
	_power_row.position = POWER_ROW_POSITION
	_power_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_row.add_theme_constant_override("separation", 4)
	add_child(_power_row)
	for i: int in hero.powers.slots.size():
		var view: PowerSlotView = PowerSlotView.new(hero.powers, i, Hero.POWER_ACTIONS[mini(i, Hero.POWER_ACTIONS.size() - 1)])
		_power_row.add_child(view)
		_power_views.append(view)
	hero.powers.changed.connect(func() -> void: _power_row.visible = hero.powers.power_count() > 0)
	hero.power_denied.connect(func(slot: int) -> void:
		if slot < _power_views.size():
			_power_views[slot].deny())
	_power_row.visible = hero.powers.power_count() > 0


func power_views() -> Array[PowerSlotView]:
	return _power_views


func _on_boss_health_changed(current: int, maximum: int) -> void:
	boss_bar.max_value = maximum
	create_tween().tween_property(boss_bar, "value", float(current), 0.12)


func _refresh_loot() -> void:
	var parts: PackedStringArray = []
	for currency: StringName in _currencies:
		var color: String = Wallet.currency_color(currency).to_html(false)
		parts.append("[color=#%s]%s %d[/color]" % [color, Wallet.currency_name(currency), _wallet.amount(currency)])
	loot_label.text = "   ".join(parts)


func _on_health_changed(current: int, maximum: int) -> void:
	hp_bar.max_value = maximum
	create_tween().tween_property(hp_bar, "value", float(current), 0.12)
	hp_label.text = "%d / %d" % [current, maximum]


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current


func _on_flasks_changed(charges: int, max_charges: int) -> void:
	flask_label.text = "Flasks  %d / %d" % [charges, max_charges]
	flask_label.modulate = Color(1, 1, 1, 1.0 if charges > 0 else 0.45)


## Dodge pressed without enough stamina: the bar blinks red and nudges sideways.
func _on_dodge_denied() -> void:
	if _denied_tween != null:
		_denied_tween.kill()
	stamina_bar.modulate = DENIED_COLOR
	stamina_bar.position.x = 0.0
	_denied_tween = create_tween()
	_denied_tween.tween_property(stamina_bar, "position:x", 3.0, 0.04)
	_denied_tween.tween_property(stamina_bar, "position:x", -2.0, 0.05)
	_denied_tween.tween_property(stamina_bar, "position:x", 0.0, 0.04)
	_denied_tween.tween_property(stamina_bar, "modulate", Color.WHITE, 0.2)
