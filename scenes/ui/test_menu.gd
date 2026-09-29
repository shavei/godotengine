class_name TestMenu
extends Control
## Test shortcuts (debug builds only, from the title): one press jumps to what the
## playtest checklist asks about. Boss buttons start a run at that fight; the rest change
## the profile (saved at once) and stay here, so several can be combined before going to
## the village. Rules live in TestShortcuts and ConsoleCommands.

const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const VILLAGE_SCENE: String = "res://scenes/village/village.tscn"
const RUN_ROOM_SCENE: String = "res://scenes/run/room.tscn"
const START_REGION: StringName = &"mossy_hollow"
const INK: Color = Color(0.95, 0.9, 0.78)
const GOLD: Color = Color(1, 0.78, 0.45)
const DIM: Color = Color(0.85, 0.8, 0.72)

## False in tests: profile changes are not written to disk.
var save_changes: bool = true

var _status: Label
var _god_button: Button
var _first_button: Button


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.12, 0.09, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title: Label = _label("Test shortcuts", 18, GOLD)
	title.position = Vector2(0, 8)
	title.size = Vector2(640, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var note: Label = _label("For the playtest checklist. Only in the editor, never in playtest builds.", 8, DIM)
	note.position = Vector2(0, 32)
	note.size = Vector2(640, 12)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(note)

	var columns: HBoxContainer = HBoxContainer.new()
	columns.position = Vector2(40, 54)
	columns.size = Vector2(560, 230)
	columns.add_theme_constant_override("separation", 20)
	add_child(columns)

	var fights: VBoxContainer = _column(columns, "Fights (D6, D7, F1)")
	_add(fights, "Fight Mother Toad", fight_boss.bind(0), "ToadButton")
	_add(fights, "Fight the Warden", fight_boss.bind(-1), "WardenButton")
	_god_button = _add(fights, "", toggle_god_mode, "GodButton")

	var powers: VBoxContainer = _column(columns, "Powers (F, G)")
	for power_id: StringName in [&"fire", &"frost", &"growth", &"stone"]:
		_add(powers, "%s waits at the Shrine" % String(power_id).capitalize(), offer_power.bind(power_id), "Offer%sButton" % String(power_id).capitalize())
	_add(powers, "Keep 3 powers, level 1", keep_powers.bind(1), "KeepLevel1Button")
	_add(powers, "Keep 3 powers, level 5", keep_powers.bind(5), "KeepLevel5Button")

	var village: VBoxContainer = _column(columns, "Village (H, I)")
	_add(village, "+1 run of training", add_training.bind(1), "Train1Button")
	_add(village, "+3 runs of training", add_training.bind(3), "Train3Button")
	_add(village, "+5 Renown", add_renown.bind(5), "RenownButton")
	_add(village, "Go to the village", func() -> void: SceneRouter.go(VILLAGE_SCENE), "VillageButton")

	_status = _label("", 9, DIM)
	_status.position = Vector2(20, 292)
	_status.size = Vector2(600, 20)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	add_child(_status)
	var back: Button = _button("Back", close)
	back.name = "BackButton"
	back.position = Vector2(265, 322)
	back.size = Vector2(110, 18)
	add_child(back)
	_refresh_god_mode()
	_status.text = "Profile changes save at once. Esc / B goes back."
	_first_button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	SceneRouter.go(TITLE_SCENE)


func status_text() -> String:
	return _status.text


## Starts a run at floor `floor_index`'s exit fight (-1 for the last floor).
func fight_boss(floor_index: int) -> void:
	var region: RegionData = ContentDB.get_item(&"regions", START_REGION) as RegionData
	var target: int = region.floor_count - 1 if floor_index < 0 else floor_index
	GameState.end_run()
	GameState.run = TestShortcuts.boss_run(region, target, randi())
	SceneRouter.go(RUN_ROOM_SCENE)


func toggle_god_mode() -> void:
	Hero.god_mode = not Hero.god_mode
	_refresh_god_mode()
	_status.text = "God mode on: you take no damage until the game closes." if Hero.god_mode else "God mode off."


func offer_power(power_id: StringName) -> void:
	var powers: Array[PowerData] = []
	for item: Resource in ContentDB.get_all(&"powers"):
		powers.append(item as PowerData)
	_apply(ConsoleCommands.give_power(_hero(), power_id, powers))


func keep_powers(level: int) -> void:
	var balance: BalanceData = GameState.balance()
	var ids: Array[StringName] = [&"fire", &"frost", &"stone"]
	_status.text = TestShortcuts.keep_powers(_hero(), ids, mini(level, balance.power_level_cap), balance.kept_power_slots)
	_save()


func add_training(count: int) -> void:
	_status.text = TestShortcuts.add_training_runs(GameState.profile, count)
	_save()


func add_renown(points: int) -> void:
	_apply(ConsoleCommands.add_renown(GameState.profile.village, points, GameState.balance()))


func _apply(result: Dictionary) -> void:
	_status.text = str(result.get("text", ""))
	if bool(result.get("changed", false)):
		_save()


func _save() -> void:
	if save_changes:
		GameState.save_profile()


func _hero() -> HeroState:
	return GameState.hero_state(GameState.LOCAL_PLAYER_ID)


func _refresh_god_mode() -> void:
	_god_button.text = "God mode: %s" % ("on" if Hero.god_mode else "off")


func _column(parent: Container, heading: String) -> VBoxContainer:
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(173, 0)
	column.add_theme_constant_override("separation", 4)
	parent.add_child(column)
	var label: Label = _label(heading, 10, GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	return column


func _add(column: VBoxContainer, text: String, callback: Callable, node_name: String) -> Button:
	var button: Button = _button(text, callback)
	button.name = node_name
	column.add_child(button)
	if _first_button == null:
		_first_button = button
	return button


func _button(text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 18)
	button.add_theme_font_size_override(&"font_size", 9)
	button.pressed.connect(callback)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
