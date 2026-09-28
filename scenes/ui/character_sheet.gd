class_name CharacterSheet
extends PanelContainer
## The hero at a glance (docs/GDD.md Section 13): level and XP, attributes, max HP in runs,
## the weapon with its tier and mastery, kept powers and their levels, and every Technique
## a Master taught, with who taught it. Opened with the Map button in the village; Close,
## Back, Map or Esc shuts it (`closed`). Read only. Fusions join it in M6.

signal closed

const GOLD: Color = Color(1, 0.78, 0.45)
const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.72, 0.67, 0.6)
const PANEL: Color = Color(0.14, 0.11, 0.09, 0.96)
const WIDTH: float = 420.0
const WEAPON_ID: StringName = &"sword"

var player_id: int = GameState.LOCAL_PLAYER_ID
var hero: HeroState
var balance: BalanceData

var _rows: VBoxContainer
var _close: Button


func setup(for_player: int, tuning: BalanceData) -> void:
	player_id = for_player
	hero = GameState.hero_state(player_id)
	balance = tuning


func _ready() -> void:
	name = "CharacterSheet"
	if hero == null:
		setup(player_id, GameState.balance())
	add_theme_stylebox_override("panel", _box(PANEL, GOLD))
	custom_minimum_size = Vector2(WIDTH, 0)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 3)
	add_child(_rows)
	_rows.add_child(_label("Your hero", 11, GOLD, "Title"))
	_rows.add_child(_label(level_text(), 8, INK, "Level"))
	_rows.add_child(_label(attributes_text(), 8, INK, "Attributes"))
	_rows.add_child(_label(weapon_text(), 8, INK, "Weapon"))
	_rows.add_child(_label(powers_text(), 8, INK, "Powers"))
	_rows.add_child(_label("Techniques", 10, GOLD, "TechniquesTitle"))
	var list: VBoxContainer = VBoxContainer.new()
	list.name = "Techniques"
	list.add_theme_constant_override("separation", 2)
	_rows.add_child(list)
	var learned: Array[TechniqueData] = GameState.techniques(player_id)
	if learned.is_empty():
		list.add_child(_label("None yet. A villager who reaches Master teaches you one.", 8, DIM, "None"))
	for technique: TechniqueData in learned:
		list.add_child(_label(technique_text(technique), 8, INK, String(technique.id).to_pascal_case()))
	_close = Button.new()
	_close.name = "CloseButton"
	_close.text = "Close"
	_close.add_theme_font_size_override("font_size", 9)
	_close.pressed.connect(close)
	_rows.add_child(_close)
	_close.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause") or event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		close()


func level_text() -> String:
	return "Level %d    XP %d / %d    Unspent points: %d" % [
		hero.level, hero.xp, ProgressionSystem.xp_to_next(hero, balance), hero.attribute_points]


## Attributes and max HP in a run (with the village's services and Techniques).
func attributes_text() -> String:
	var stack: ModifierStack = GameState.services(player_id)
	var max_hp: int = roundi(stack.total(ModifierStack.MAX_HP, ProgressionSystem.max_hp(hero, balance)) * (1.0 + stack.total(ModifierStack.MAX_HP_SHARE)))
	return "Might %d    Vigor %d    Focus %d    Max HP in runs: %d" % [
		hero.attribute(HeroState.MIGHT), hero.attribute(HeroState.VIGOR), hero.attribute(HeroState.FOCUS), max_hp]


func weapon_text() -> String:
	var weapon: WeaponData = ContentDB.get_item(&"weapons", WEAPON_ID) as WeaponData
	var weapon_name: String = weapon.display_name if weapon != null else String(WEAPON_ID).capitalize()
	return "%s %s    Mastery %d" % [ShopSystem.tier_name(hero.weapon_tier(WEAPON_ID), balance), weapon_name,
			ProgressionSystem.mastery_level(hero.mastery_xp(WEAPON_ID), balance)]


func powers_text() -> String:
	if hero.kept_powers.is_empty():
		return "Kept powers: none"
	var names: PackedStringArray = []
	for kept: KeptPower in hero.kept_powers:
		var power: PowerData = ContentDB.get_item(&"powers", kept.power_id) as PowerData
		names.append("%s Lv %d" % [power.display_name if power != null else String(kept.power_id), kept.level])
	return "Kept powers: " + ", ".join(names)


## "Ember Step: Your dodge leaves ... (Taught by Bram the Smith)".
func technique_text(technique: TechniqueData) -> String:
	var text: String = "%s: %s" % [technique.display_name, technique.description]
	var combo: ComboData = TechniqueSystem.teacher(GameState.combos(), technique.id)
	var teacher: VillagerData = ContentDB.get_item(&"villagers", combo.villager_id) as VillagerData if combo != null else null
	if teacher != null:
		text += " (Taught by %s)" % teacher.title()
	return text


func close() -> void:
	closed.emit()
	queue_free()


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(8)
	return style


func _label(text: String, font_size: int, color: Color, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(WIDTH - 16, 0)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
