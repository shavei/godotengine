class_name ResultsScreen
extends Control
## The results screen (docs/GDD.md Section 13): how the run went, XP and level-ups,
## weapon mastery, and the loot found and kept. Level-ups give attribute points to spend
## here. Reads SceneRouter.context["summary"] (a RunSummary for the local hero).
## Continue goes to the title until the village exists (M4).

const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const GOLD: Color = Color(1, 0.78, 0.45)
const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.72, 0.67, 0.6)
const FELL: Color = Color(0.95, 0.5, 0.45)
const GOOD: Color = Color(0.6, 0.95, 0.55)
const ATTRIBUTE_TEXT: Dictionary = {
	HeroState.MIGHT: ["Might", "+3% weapon damage"],
	HeroState.VIGOR: ["Vigor", "+10 max HP, +5 stamina"],
	HeroState.FOCUS: ["Focus", "stronger powers (powers come later)"],
}
## Loot rows, in HUD order. The region material is added from the summary.
const LOOT_ORDER: Array[StringName] = [Wallet.COINS, Wallet.WOOD, Wallet.ORE, Wallet.CRYSTAL, Wallet.SHARDS]

var summary: RunSummary
var hero: HeroState
var balance: BalanceData
## Save the profile after each spent point (tests turn it off).
var save_on_spend: bool = true

var _points_label: Label
var _attribute_buttons: Dictionary[StringName, Button] = {}
var _continue: Button


func _ready() -> void:
	summary = SceneRouter.context.get("summary") as RunSummary
	if summary == null:
		summary = RunSummary.new()
	hero = GameState.hero_state(summary.player_id)
	balance = ContentDB.get_item(&"balance", &"default") as BalanceData
	if balance == null:
		balance = BalanceData.new()
	_build()
	refresh()
	var first_points: Button = _attribute_buttons.get(HeroState.MIGHT)
	if hero.attribute_points > 0 and first_points != null:
		first_points.grab_focus()
	else:
		_continue.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		continue_on()


func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.12, 0.09, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var headline: String = "%s cleared!" % summary.region_name if summary.success \
			else "You fell on floor %d of %d" % [summary.floor_reached, summary.floor_count]
	_place(_label(headline, 18, GOLD if summary.success else FELL, "Headline"), Vector2(0, 10), Vector2(640, 26), true)
	_place(_label("Time %s    Rooms cleared %d" % [summary.time_text(), summary.rooms_cleared], 9, DIM, "Stats"),
			Vector2(0, 36), Vector2(640, 14), true)

	# Left: experience and mastery.
	var left: VBoxContainer = _column(Vector2(60, 64), "Experience")
	left.add_child(_label("+%d XP" % summary.xp_gained, 14, GOOD, "XpGained"))
	var level_text: String = "Level %d" % summary.level_after
	if summary.levels_gained() > 0:
		level_text = "Level %d > %d. Level up!" % [summary.level_before, summary.level_after]
	left.add_child(_label(level_text, 10, GOLD if summary.levels_gained() > 0 else INK, "Level"))
	var bar: ProgressBar = ProgressBar.new()
	bar.name = "XpBar"
	bar.custom_minimum_size = Vector2(220, 8)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _bar_style(Color(0.24, 0.2, 0.17)))
	bar.add_theme_stylebox_override("fill", _bar_style(GOOD.darkened(0.2)))
	bar.max_value = maxi(summary.xp_for_next, 1)
	bar.value = float(summary.xp_into_level) if summary.xp_for_next > 0 else bar.max_value
	left.add_child(bar)
	var next_text: String = "%d / %d XP to level %d" % [summary.xp_into_level, summary.xp_for_next, summary.level_after + 1] \
			if summary.xp_for_next > 0 else "Highest level"
	left.add_child(_label(next_text, 8, DIM, "NextLevel"))
	if summary.weapon_id != &"":
		var mastery: String = "%s mastery +%d XP (mastery %d)" % [_weapon_name(summary.weapon_id), summary.mastery_xp_gained, summary.mastery_after]
		if summary.mastery_after > summary.mastery_before:
			mastery += ". Up!"
		left.add_child(_label(mastery, 9, INK, "Mastery"))

	# Right: loot found and kept.
	var right: VBoxContainer = _column(Vector2(360, 64), "Loot")
	var grid: GridContainer = GridContainer.new()
	grid.name = "LootGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	right.add_child(grid)
	for text: String in ["", "Found", "Kept"]:
		grid.add_child(_label(text, 8, DIM))
	for currency: StringName in _loot_rows():
		grid.add_child(_label(Wallet.currency_name(currency), 9, Wallet.currency_color(currency)))
		grid.add_child(_label(str(summary.found.get(currency, 0)), 9, INK))
		var kept: int = summary.kept.get(currency, 0)
		grid.add_child(_label(str(kept), 9, INK if kept == summary.found.get(currency, 0) else FELL))
	if _loot_rows().is_empty():
		right.add_child(_label("Nothing picked up.", 9, DIM))
	var note: String = "Everything comes home with you." if summary.success \
			else "You fell, so you kept %d%% of your loot. XP and mastery are kept in full." % roundi(summary.keep_fraction * 100.0)
	var note_label: Label = _label(note, 8, DIM, "LootNote")
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	note_label.custom_minimum_size = Vector2(220, 0)
	right.add_child(note_label)

	# Bottom: attribute points and Continue.
	_points_label = _label("", 10, GOLD, "Points")
	_place(_points_label, Vector2(0, 206), Vector2(640, 16), true)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_place(row, Vector2(20, 226), Vector2(600, 40), false)
	for attribute_id: StringName in HeroState.ATTRIBUTES:
		var button: Button = Button.new()
		button.name = "%sButton" % ATTRIBUTE_TEXT[attribute_id][0]
		button.custom_minimum_size = Vector2(186, 36)
		button.add_theme_font_size_override("font_size", 9)
		button.pressed.connect(spend.bind(attribute_id))
		row.add_child(button)
		_attribute_buttons[attribute_id] = button
	_continue = Button.new()
	_continue.name = "ContinueButton"
	_continue.text = "Continue"
	_continue.add_theme_font_size_override("font_size", 10)
	_continue.pressed.connect(continue_on)
	_place(_continue, Vector2(260, 300), Vector2(120, 24), false)


func refresh() -> void:
	var points: int = hero.attribute_points
	_points_label.text = "%d attribute point%s to spend" % [points, "" if points == 1 else "s"] if points > 0 \
			else "Level %d hero: %d HP" % [hero.level, ProgressionSystem.max_hp(hero, balance)]
	for attribute_id: StringName in _attribute_buttons:
		var button: Button = _attribute_buttons[attribute_id]
		var info: Array = ATTRIBUTE_TEXT[attribute_id]
		button.text = "%s %d\n%s" % [info[0], hero.attribute(attribute_id), info[1]]
		# Focus does nothing until kept powers exist (M3), so no point goes there yet.
		button.disabled = attribute_id == HeroState.FOCUS or not ProgressionSystem.can_spend_point(hero, attribute_id, balance)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
	if _continue != null and get_viewport() != null and get_viewport().gui_get_focus_owner() == null:
		_continue.grab_focus()


## Spends one attribute point and saves the profile.
func spend(attribute_id: StringName) -> void:
	if attribute_id == HeroState.FOCUS or not ProgressionSystem.spend_point(hero, attribute_id, balance):
		return
	if save_on_spend:
		GameState.save_profile()
	refresh()


func continue_on() -> void:
	SceneRouter.go(TITLE_SCENE)


func _loot_rows() -> Array[StringName]:
	var rows: Array[StringName] = []
	for currency: StringName in LOOT_ORDER:
		if summary.found.get(currency, 0) > 0:
			rows.append(currency)
	for currency: StringName in summary.found:
		if not rows.has(currency) and summary.found[currency] > 0:
			rows.append(currency)
	return rows


func _weapon_name(weapon_id: StringName) -> String:
	var weapon: WeaponData = ContentDB.get_item(&"weapons", weapon_id) as WeaponData
	return weapon.display_name if weapon != null else String(weapon_id).capitalize()


func _bar_style(color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style


func _column(at: Vector2, heading: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	_place(column, at, Vector2(240, 130), false)
	column.add_child(_label(heading, 11, GOLD))
	return column


func _place(node: Control, at: Vector2, size_px: Vector2, centered: bool) -> void:
	node.position = at
	node.size = size_px
	if centered and node is Label:
		(node as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(node)


func _label(text: String, font_size: int, color: Color, node_name: String = "") -> Label:
	var label: Label = Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
