class_name ShopPanel
extends PanelContainer
## A villager's shop in the village (docs/GDD.md Section 5.1), opened by talking to a
## villager who sells something: the Smith's next weapon tier, and a priced service
## their power gives (an infusion, bought once). Pays from the hero's banked coins
## (ShopSystem) and saves. Cancel or Close shuts it (`closed`).

signal closed
## Something was bought: a weapon tier (&"tier") or the combo id of a service.
signal bought(item_id: StringName)

const TIER: StringName = &"tier"
const GOLD: Color = Color(1, 0.78, 0.45)
const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.72, 0.67, 0.6)
const GOOD: Color = Color(0.6, 0.95, 0.55)
const PANEL: Color = Color(0.14, 0.11, 0.09, 0.96)
const WIDTH: float = 300.0

var player_id: int = GameState.LOCAL_PLAYER_ID
var hero: HeroState
var village: VillageState
var balance: BalanceData
var villager: VillagerState
var data: VillagerData
var weapon: WeaponData
## The combo whose priced service is for sale, or null.
var combo: ComboData
## Save the profile after a purchase (tests turn it off).
var save_on_buy: bool = true

var _rows: VBoxContainer
var _coins: Label
var _note: Label
var _buttons: Array[Button] = []
var _close: Button


## True if this villager has anything to sell (weapon tiers, or a priced service).
static func sells_anything(villager_data: VillagerData, villager_state: VillagerState) -> bool:
	if villager_data == null:
		return false
	if villager_data.base_service != null and villager_data.base_service.sells_weapon_tiers:
		return true
	return _priced_combo(villager_data, villager_state) != null


static func _priced_combo(villager_data: VillagerData, villager_state: VillagerState) -> ComboData:
	if villager_state == null or not villager_state.has_power():
		return null
	var found: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(villager_data.id, villager_state.power_id)) as ComboData
	return found if found != null and found.novice != null and found.novice.price > 0 else null


## Sets up the shop for one villager and hero. Call before adding it to the tree.
func setup(for_player: int, villager_state: VillagerState, villager_data: VillagerData, hero_weapon: WeaponData, tuning: BalanceData) -> void:
	player_id = for_player
	hero = GameState.hero_state(player_id)
	village = GameState.profile.village
	villager = villager_state
	data = villager_data
	weapon = hero_weapon
	balance = tuning
	combo = _priced_combo(data, villager)


func _ready() -> void:
	name = "ShopPanel"
	add_theme_stylebox_override("panel", _box(PANEL, data.color if data != null else GOLD))
	custom_minimum_size = Vector2(WIDTH, 0)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	add_child(_rows)
	_rows.add_child(_label("%s: %s" % [data.title(), data.workplace], 11, data.color.lightened(0.2), "Title"))
	_coins = _label("", 8, Wallet.currency_color(Wallet.COINS), "Coins")
	_rows.add_child(_coins)
	if data.base_service != null and data.base_service.sells_weapon_tiers and weapon != null:
		_buttons.append(_add_button(TIER, "TierButton"))
	if combo != null:
		_buttons.append(_add_button(combo.id, "ServiceButton"))
	_note = _label("", 7, DIM, "Note")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(WIDTH - 12, 0)
	_rows.add_child(_note)
	_close = Button.new()
	_close.name = "CloseButton"
	_close.text = "Close"
	_close.add_theme_font_size_override("font_size", 9)
	_close.pressed.connect(close)
	_rows.add_child(_close)
	refresh()
	_focus_first()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func refresh() -> void:
	_coins.text = "Your coins: %d    Crystal: %d" % [hero.bank.amount(Wallet.COINS), hero.bank.amount(Wallet.CRYSTAL)]
	for button: Button in _buttons:
		var item: StringName = button.get_meta(&"item")
		var problem: String = _problem(item)
		button.text = _item_text(item) + ("" if problem.is_empty() else "\n" + problem)
		button.disabled = not problem.is_empty()
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	if get_viewport() != null:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused == null or (focused is Button and (focused as Button).disabled):
			_focus_first()


## Buys the next weapon tier. Returns true if it did.
func buy_tier() -> bool:
	var tier: int = ShopSystem.buy_tier(hero, weapon.id, villager, _forge(), balance)
	if tier < 0:
		return false
	_after_buy(TIER, "Your %s is %s now: %s damage." % [weapon.display_name, ShopSystem.tier_name(tier, balance), _times(ShopSystem.tier_multiplier(tier, balance))])
	return true


## Buys the priced service once. Returns true if it did.
func buy_service() -> bool:
	if not ShopSystem.buy_service(hero, combo):
		return false
	_after_buy(combo.id, "%s is yours for every run." % _service_name())
	return true


func close() -> void:
	closed.emit()
	queue_free()


func _after_buy(item: StringName, message: String) -> void:
	if save_on_buy:
		GameState.save_profile()
	EventBus.village_purchase.emit(player_id, item)
	bought.emit(item)
	refresh()
	_note.text = message


func _on_pressed(item: StringName) -> void:
	if item == TIER:
		buy_tier()
	else:
		buy_service()


func _problem(item: StringName) -> String:
	if item == TIER:
		return ShopSystem.tier_problem(hero, weapon.id, villager, _forge(), balance)
	if hero.has_bought(combo.id):
		return "Yours already."
	return ShopSystem.service_problem(hero, combo)


func _item_text(item: StringName) -> String:
	if item == TIER:
		var tier: int = ShopSystem.next_tier(hero, weapon.id, balance)
		var current: String = ShopSystem.tier_name(hero.weapon_tier(weapon.id), balance)
		if tier < 0:
			return "%s %s" % [current, weapon.display_name]
		var price: String = "%d coins" % ShopSystem.tier_price(tier, balance)
		if ShopSystem.tier_crystal(tier, balance) > 0:
			price += " and %d Crystal" % ShopSystem.tier_crystal(tier, balance)
		return "%s %s: %s damage (now %s)\n%s" % [ShopSystem.tier_name(tier, balance), weapon.display_name,
				_times(ShopSystem.tier_multiplier(tier, balance)), current, price]
	return "%s\n%d coins, once" % [combo.novice.description, combo.novice.price]


func _service_name() -> String:
	return combo.novice.shop_name if not combo.novice.shop_name.is_empty() else "Service"


func _forge() -> int:
	return ShopSystem.forge_level(village, villager.villager_id, GameState.services(player_id))


func _times(value: float) -> String:
	return "x%s" % String.num(value, 1)


func _add_button(item: StringName, node_name: String) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.set_meta(&"item", item)
	button.add_theme_font_size_override("font_size", 8)
	button.autowrap_mode = TextServer.AUTOWRAP_WORD
	button.custom_minimum_size = Vector2(WIDTH - 12, 0)
	button.pressed.connect(_on_pressed.bind(item))
	_rows.add_child(button)
	return button


func _focus_first() -> void:
	if get_viewport() == null:
		return
	for button: Button in _buttons:
		if not button.disabled:
			button.grab_focus()
			return
	_close.grab_focus()


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	return style


func _label(text: String, font_size: int, color: Color, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
