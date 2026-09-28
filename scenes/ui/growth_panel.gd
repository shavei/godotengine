class_name GrowthPanel
extends VBoxContainer
## The Shrine's "Grow stronger" view (docs/GDD.md Sections 4.1 and 4.3): spend attribute
## points on Might, Vigor or Focus, spend banked Power Shards to level up kept powers,
## and reset attributes for coins (a second press confirms). Saves after each change.

## Something was spent.
signal changed

const GOLD: Color = Color(1, 0.78, 0.45)
const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.72, 0.67, 0.6)
const ATTRIBUTE_TEXT: Dictionary = {
	HeroState.MIGHT: ["Might", "+3% weapon damage"],
	HeroState.VIGOR: ["Vigor", "+10 max HP, +5 stamina"],
	HeroState.FOCUS: ["Focus", "+3% power damage, -1.5% cooldowns"],
}

var player_id: int = GameState.LOCAL_PLAYER_ID
var hero: HeroState
var balance: BalanceData
## Save the profile after each change (tests turn it off).
var save_on_spend: bool = true

var _points_label: Label
var _attribute_buttons: Dictionary[StringName, Button] = {}
var _shards_label: Label
## What the focused power's next upgrade does.
var _power_note: Label
## One button per kept power, in slot order.
var _power_buttons: Array[Button] = []
var _respec: Button
var _respec_armed: bool = false


## True while there is a point to spend or a kept power the shards can level.
static func has_anything_to_spend(state: HeroState, tuning: BalanceData) -> bool:
	if state.attribute_points > 0:
		return true
	for kept: KeptPower in state.kept_powers:
		if GiftSystem.can_level_up(state, kept.power_id, tuning):
			return true
	return false


func setup(for_player: int, tuning: BalanceData) -> void:
	player_id = for_player
	hero = GameState.hero_state(player_id)
	balance = tuning


func _ready() -> void:
	name = "GrowthPanel"
	add_theme_constant_override("separation", 5)
	if hero == null:
		setup(player_id, BalanceData.new())
	_points_label = _label("", 10, GOLD, "Points")
	add_child(_points_label)
	var row: HBoxContainer = _row("AttributeRow")
	for attribute_id: StringName in HeroState.ATTRIBUTES:
		var button: Button = Button.new()
		button.name = "%sButton" % ATTRIBUTE_TEXT[attribute_id][0]
		button.custom_minimum_size = Vector2(186, 34)
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(spend.bind(attribute_id))
		row.add_child(button)
		_attribute_buttons[attribute_id] = button
	_shards_label = _label("", 9, Wallet.currency_color(Wallet.SHARDS), "Shards")
	add_child(_shards_label)
	var power_row: HBoxContainer = _row("PowerRow")
	for kept: KeptPower in hero.kept_powers:
		var button: Button = Button.new()
		button.name = "%sLevelButton" % String(kept.power_id).capitalize()
		button.custom_minimum_size = Vector2(186, 26)
		button.add_theme_font_size_override("font_size", 8)
		button.pressed.connect(level_up.bind(kept.power_id))
		button.focus_entered.connect(_show_power_note.bind(kept.power_id))
		button.mouse_entered.connect(_show_power_note.bind(kept.power_id))
		power_row.add_child(button)
		_power_buttons.append(button)
	_power_note = _label("", 8, DIM, "PowerNote")
	add_child(_power_note)
	var respec_row: HBoxContainer = _row("RespecRow")
	_respec = Button.new()
	_respec.name = "RespecButton"
	_respec.add_theme_font_size_override("font_size", 8)
	_respec.pressed.connect(_on_respec_pressed)
	_respec.focus_exited.connect(_disarm_respec)
	respec_row.add_child(_respec)
	refresh()


func refresh() -> void:
	var points: int = hero.attribute_points
	_points_label.text = "%d attribute point%s to spend" % [points, "" if points == 1 else "s"] if points > 0 \
			else "Level %d hero: %d HP" % [hero.level, ProgressionSystem.max_hp(hero, balance)]
	for attribute_id: StringName in _attribute_buttons:
		var button: Button = _attribute_buttons[attribute_id]
		var info: Array = ATTRIBUTE_TEXT[attribute_id]
		button.text = "%s %d\n%s" % [info[0], hero.attribute(attribute_id), info[1]]
		_set_enabled(button, ProgressionSystem.can_spend_point(hero, attribute_id, balance))
	_refresh_powers()
	_refresh_respec()


## Points to spend first, then a power the shards can level, or null.
func default_focus() -> Button:
	for button: Button in _attribute_buttons.values():
		if not button.disabled:
			return button
	for button: Button in _power_buttons:
		if not button.disabled:
			return button
	return null


## Spends one attribute point and saves the profile.
func spend(attribute_id: StringName) -> void:
	if not ProgressionSystem.spend_point(hero, attribute_id, balance):
		return
	_after_change()


## Spends banked shards on the next level of a kept power and saves the profile.
func level_up(power_id: StringName) -> void:
	var new_level: int = GiftSystem.level_up(hero, power_id, balance, GameState.profile.run_count)
	if new_level == 0:
		return
	EventBus.power_leveled.emit(player_id, power_id, new_level)
	_after_change()
	_show_power_note(power_id)


## Resets every attribute for coins. Returns true if it did.
func respec() -> bool:
	if not ProgressionSystem.respec(hero, balance):
		return false
	_after_change()
	return true


func _after_change() -> void:
	if save_on_spend:
		GameState.save_profile()
	refresh()
	changed.emit()


func _on_respec_pressed() -> void:
	if not _respec_armed:
		_respec_armed = true
		_respec.text = "Sure? Pay %d coins to reset every point" % ProgressionSystem.respec_cost(hero, balance)
		return
	_respec_armed = false
	respec()


func _disarm_respec() -> void:
	if _respec_armed:
		_respec_armed = false
		_refresh_respec()


func _refresh_respec() -> void:
	var cost: int = ProgressionSystem.respec_cost(hero, balance)
	_respec.text = "Reset attributes: %d coins (you have %d)" % [cost, hero.bank.amount(Wallet.COINS)]
	_set_enabled(_respec, ProgressionSystem.can_respec(hero, balance))


func _refresh_powers() -> void:
	var shards: int = hero.bank.amount(Wallet.SHARDS)
	_shards_label.text = "No kept powers yet. Power Shards: %d" % shards if hero.kept_powers.is_empty() \
			else "Power Shards: %d. Spend them to level up a kept power." % shards
	for i: int in _power_buttons.size():
		var button: Button = _power_buttons[i]
		var kept: KeptPower = hero.kept_powers[i] if i < hero.kept_powers.size() else null
		if kept == null:
			button.hide()
			continue
		var power: PowerData = ContentDB.get_item(&"powers", kept.power_id) as PowerData
		var power_name: String = power.display_name if power != null else String(kept.power_id).capitalize()
		if kept.level >= balance.power_level_cap:
			button.text = "%s level %d\nHighest level" % [power_name, kept.level]
		else:
			var cost: int = PowerRules.level_up_cost(kept.level, balance)
			button.text = "%s level %d > %d\n%d shards" % [power_name, kept.level, kept.level + 1, cost]
		_set_enabled(button, GiftSystem.can_level_up(hero, kept.power_id, balance))


## Shows what the next level of a kept power brings (every level: +20% damage; levels 3
## and 5 add their upgrade).
func _show_power_note(power_id: StringName) -> void:
	var kept: KeptPower = GiftSystem.find(hero, power_id)
	var power: PowerData = ContentDB.get_item(&"powers", power_id) as PowerData
	if kept == null or power == null:
		_power_note.text = ""
		return
	var next_level: int = kept.level + 1
	if kept.level >= balance.power_level_cap:
		_power_note.text = "%s is at its highest level." % power.ability_name
	elif next_level == PowerRules.UPGRADE_LEVELS[0]:
		_power_note.text = "%s level 3: %s" % [power.ability_name, power.level3_text]
	elif next_level == PowerRules.UPGRADE_LEVELS[1]:
		_power_note.text = "%s level 5: %s" % [power.ability_name, power.level5_text]
	else:
		_power_note.text = "%s level %d: +%d%% power damage." % [power.ability_name, next_level, roundi(balance.power_damage_per_level * 100.0)]


func _set_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _row(node_name: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = node_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	return row


func _label(text: String, font_size: int, color: Color, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
