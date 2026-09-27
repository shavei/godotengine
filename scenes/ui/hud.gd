class_name Hud
extends CanvasLayer
## Run HUD (docs/GDD.md Section 13): HP, stamina, flasks and, in runs, what the hero
## has picked up. Call bind_hero() once (and bind_wallet() in runs); the HUD then
## follows their signals.

const DENIED_COLOR: Color = Color(1.0, 0.3, 0.3)

@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var stamina_bar: ProgressBar = %StaminaBar
@onready var flask_label: Label = %FlaskLabel
@onready var loot_label: RichTextLabel = %LootLabel

var _denied_tween: Tween
var _wallet: Wallet
var _currencies: Array[StringName] = []


func bind_hero(hero: Hero) -> void:
	hero.health.health_changed.connect(_on_health_changed)
	hero.stamina.changed.connect(_on_stamina_changed)
	hero.flasks.changed.connect(_on_flasks_changed)
	hero.dodge_denied.connect(_on_dodge_denied)
	_on_health_changed(hero.health.hp, hero.health.max_hp)
	_on_stamina_changed(hero.stamina.current, hero.stamina.maximum)
	_on_flasks_changed(hero.flasks.charges, hero.flasks.max_charges)


## Shows `currencies` from `wallet`, in that order (coins, region material, Crystal, shards).
func bind_wallet(wallet: Wallet, currencies: Array[StringName]) -> void:
	_wallet = wallet
	_currencies = currencies
	wallet.changed.connect(func(_currency: StringName, _amount: int) -> void: _refresh_loot())
	loot_label.show()
	_refresh_loot()


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
