class_name ChoiceScreen
extends Control
## The keep screen (docs/GDD.md Section 3.1, the Choice screen without Give until the
## village exists in M4). Settles the hero's power offer (HeroState.power_offer):
## first take one orb if none was taken in the boss room, then Keep it in a free slot,
## Merge it into the same kept power (+1 level), let a kept power go to make room, or
## leave it behind. Letting go and leaving ask for a second press.
## Reads SceneRouter.context["player_id"] (the local hero by default).

const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const GOLD: Color = Color(1, 0.78, 0.45)
const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.72, 0.67, 0.6)
const WARN: Color = Color(0.95, 0.5, 0.45)
const GOOD: Color = Color(0.6, 0.95, 0.55)
const PANEL: Color = Color(0.2, 0.16, 0.13)
const CARD_SIZE: Vector2 = Vector2(190, 118)
const SLOT_SIZE: Vector2 = Vector2(150, 34)
const LEAVE: StringName = &"leave"

var player_id: int = GameState.LOCAL_PLAYER_ID
var hero: HeroState
var balance: BalanceData
## Save the profile after each change (tests turn it off).
var save_on_change: bool = true
## True once the offer is settled; the screen then only offers Continue.
var done: bool = false

var _headline: Label
var _subline: Label
var _cards: HBoxContainer
var _slots: HBoxContainer
var _actions: HBoxContainer
var _note: Label
## The button that asked "Sure?" and waits for a second press, or null.
var _armed: Button


func _ready() -> void:
	player_id = int(SceneRouter.context.get("player_id", GameState.LOCAL_PLAYER_ID))
	hero = GameState.hero_state(player_id)
	balance = ContentDB.get_item(&"balance", &"default") as BalanceData
	if balance == null:
		balance = BalanceData.new()
	_build()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	# Leaving early is safe: an unsettled offer waits in the save (title: "A power is waiting").
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		continue_on()


func _build() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.12, 0.09, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_headline = _label("", 18, GOLD, "Headline")
	_place(_headline, Vector2(0, 10), Vector2(640, 26))
	_subline = _label("", 9, DIM, "Subline")
	_place(_subline, Vector2(0, 36), Vector2(640, 14))
	_cards = _row("Cards", 12)
	_place(_cards, Vector2(20, 56), Vector2(600, CARD_SIZE.y))
	_place(_label("Your powers", 9, DIM, "SlotsHeading"), Vector2(0, 182), Vector2(640, 14))
	_slots = _row("Slots", 8)
	_place(_slots, Vector2(20, 198), Vector2(600, SLOT_SIZE.y))
	_actions = _row("Actions", 8)
	_place(_actions, Vector2(10, 248), Vector2(620, 30))
	_note = _label("", 8, DIM, "Note")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_place(_note, Vector2(60, 286), Vector2(520, 40))


## Rebuilds cards, slots and actions for where the offer stands now.
func refresh() -> void:
	_armed = null
	_clear(_cards)
	_clear(_slots)
	_clear(_actions)
	for i: int in GiftSystem.slot_count(balance):
		_slots.add_child(_slot_view(hero.kept_powers[i] if i < hero.kept_powers.size() else null))
	if done:
		_add_action("Continue", &"continue", "ContinueButton")
	elif PowerOffer.is_picking(hero):
		_show_pick()
	elif PowerOffer.waiting_power(hero) != &"":
		_show_decision(PowerOffer.waiting_power(hero))
	else:
		_headline.text = "No power is waiting"
		_subline.text = "Clear a region's boss to earn one."
		_note.text = ""
		_add_action("Continue", &"continue", "ContinueButton")
	_focus_first()


func _show_pick() -> void:
	_headline.text = "%d Sparks broke free" % hero.power_offer.size()
	_subline.text = "Take one. The %s for good." % ("other fades" if hero.power_offer.size() == 2 else "others fade")
	_note.text = ""
	for power_id: StringName in hero.power_offer:
		var card: Button = Button.new()
		card.name = "%sCard" % String(power_id).capitalize()
		card.custom_minimum_size = CARD_SIZE
		card.pressed.connect(take.bind(power_id))
		var power: PowerData = _power(power_id)
		var tint: Color = power.color if power != null else INK
		card.add_theme_stylebox_override("normal", _box(PANEL, tint.darkened(0.45)))
		card.add_theme_stylebox_override("hover", _box(PANEL.lightened(0.05), tint))
		card.add_theme_stylebox_override("pressed", _box(PANEL.lightened(0.1), tint))
		var focus: StyleBoxFlat = _box(Color.TRANSPARENT, tint.lightened(0.3))
		focus.set_border_width_all(2)
		card.add_theme_stylebox_override("focus", focus)
		_fill_card(card, power_id)
		_cards.add_child(card)


func _show_decision(power_id: StringName) -> void:
	var power: PowerData = _power(power_id)
	_headline.text = "A new power: %s" % _name(power_id)
	var card: PanelContainer = PanelContainer.new()
	card.name = "%sCard" % String(power_id).capitalize()
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("panel", _box(PANEL, power.color if power != null else INK))
	_fill_card(card, power_id)
	_cards.add_child(card)
	var kept: KeptPower = GiftSystem.find(hero, power_id)
	match PowerOffer.choice_for(hero, power_id, balance):
		PowerOffer.KEEP:
			_subline.text = "Keep it in a free slot, or leave it behind."
			_add_action("Keep it (slot %d)" % (hero.kept_powers.size() + 1), PowerOffer.KEEP, "KeepButton")
			_note.text = "Kept powers go on the Power buttons in your next run."
		PowerOffer.MERGE:
			_subline.text = "You keep %s already. Merge them for a level." % _name(power_id)
			_add_action("Merge: level %d > %d" % [kept.level, kept.level + 1], PowerOffer.MERGE, "MergeButton")
			_note.text = _level_note(power, kept.level + 1)
		PowerOffer.MAXED:
			_subline.text = "Your %s is at its highest level already." % _name(power_id)
			_note.text = "There is nothing to merge. Giving powers to villagers comes with the village."
		PowerOffer.REPLACE:
			_subline.text = "Every slot is full. Let a kept power go to make room, or leave this one."
			for other: KeptPower in hero.kept_powers:
				_add_action("Let %s go (lv %d)" % [_name(other.power_id), other.level], PowerOffer.REPLACE,
						"Let%sGoButton" % String(other.power_id).capitalize(), other.power_id)
			_note.text = "A power you let go is gone, with the shards spent on it. Giving it to a villager comes with the village."
	_add_action("Leave it behind", LEAVE, "LeaveButton")


## Takes one orb; the others fade.
func take(power_id: StringName) -> void:
	if not PowerOffer.take(hero, power_id):
		return
	_save()
	refresh()


## Keeps the waiting power in the next free slot.
func keep() -> bool:
	var power_id: StringName = PowerOffer.waiting_power(hero)
	var kept: KeptPower = GiftSystem.keep(hero, power_id, balance, GameState.profile.run_count)
	if kept == null:
		return false
	EventBus.power_kept.emit(player_id, power_id)
	_settle("%s is kept in slot %d." % [_name(power_id), hero.kept_powers.size()])
	return true


## Merges the waiting power into the same kept power (+1 level).
func merge() -> bool:
	var power_id: StringName = PowerOffer.waiting_power(hero)
	var new_level: int = GiftSystem.merge(hero, power_id, balance, GameState.profile.run_count)
	if new_level == 0:
		return false
	EventBus.power_merged.emit(player_id, power_id, new_level)
	_settle("%s merged: now level %d." % [_name(power_id), new_level])
	return true


## Lets `old_id` go; the waiting power takes its slot at level 1.
func replace(old_id: StringName) -> bool:
	var power_id: StringName = PowerOffer.waiting_power(hero)
	if PowerOffer.choice_for(hero, power_id, balance) != PowerOffer.REPLACE:
		return false
	var slot: int = hero.kept_powers.find(GiftSystem.find(hero, old_id))
	if GiftSystem.replace(hero, old_id, power_id, GameState.profile.run_count) == null:
		return false
	EventBus.power_kept.emit(player_id, power_id)
	_settle("%s is gone. %s is kept in slot %d." % [_name(old_id), _name(power_id), slot + 1])
	return true


## Leaves the waiting power behind.
func leave() -> void:
	var power_id: StringName = PowerOffer.waiting_power(hero)
	_settle("You left %s behind." % _name(power_id))


func continue_on() -> void:
	SceneRouter.go(TITLE_SCENE)


func _settle(message: String) -> void:
	PowerOffer.clear(hero)
	done = true
	_save()
	_headline.text = "The Choice is made"
	_subline.text = message
	_note.text = ""
	refresh()


func _save() -> void:
	if save_on_change:
		GameState.save_profile()


## Keep and Merge act at once; letting go and leaving ask "Sure?" first.
func _on_action(action: StringName, button: Button, power_id: StringName) -> void:
	match action:
		&"continue":
			continue_on()
		PowerOffer.KEEP:
			keep()
		PowerOffer.MERGE:
			merge()
		PowerOffer.REPLACE, LEAVE:
			if _armed != button:
				_arm(button, "Sure? %s is lost" % _name(power_id if action == PowerOffer.REPLACE else PowerOffer.waiting_power(hero)))
			elif action == LEAVE:
				leave()
			else:
				replace(power_id)


func _arm(button: Button, question: String) -> void:
	if _armed != null:
		_armed.text = _armed.get_meta(&"text")
	_armed = button
	button.text = question


func _add_action(text: String, action: StringName, node_name: String, power_id: StringName = &"") -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.set_meta(&"text", text)
	button.custom_minimum_size = Vector2(0, 26)
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(func() -> void: _on_action(action, button, power_id))
	_actions.add_child(button)
	return button


func _focus_first() -> void:
	if get_viewport() == null:
		return
	for row: HBoxContainer in [_cards, _actions]:
		for child: Node in row.get_children():
			if child is Button and not child.is_queued_for_deletion():
				(child as Button).grab_focus()
				return


## A power's icon, name, ability, what it does and whether the hero keeps it already.
func _fill_card(card: Control, power_id: StringName) -> void:
	var power: PowerData = _power(power_id)
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var icon: Control = Control.new()
	icon.custom_minimum_size = Vector2(0, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if power != null:
		icon.draw.connect(func() -> void:
			PowerIcon.draw(icon, power.icon_shape, Vector2(icon.size.x * 0.5, 16), 24, power.color))
	column.add_child(icon)
	column.add_child(_label(_name(power_id), 11, power.color if power != null else INK, "Name"))
	if power == null:
		return
	column.add_child(_label(power.ability_name, 9, INK, "Ability"))
	var about: Label = _label(power.description, 7, DIM, "About")
	about.autowrap_mode = TextServer.AUTOWRAP_WORD
	about.custom_minimum_size = Vector2(CARD_SIZE.x - 12, 0)
	column.add_child(about)
	var kept: KeptPower = GiftSystem.find(hero, power_id)
	column.add_child(_label("New power" if kept == null else "You keep it: level %d" % kept.level, 8, GOOD if kept == null else GOLD, "Kept"))


func _slot_view(kept: KeptPower) -> Control:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = SLOT_SIZE
	var power: PowerData = _power(kept.power_id) if kept != null else null
	panel.add_theme_stylebox_override("panel", _box(PANEL.darkened(0.3), power.color if power != null else DIM.darkened(0.4)))
	var text: String = "Empty slot" if kept == null else "%s  lv %d\n%s" % [_name(kept.power_id), kept.level, power.ability_name if power != null else ""]
	panel.add_child(_label(text, 8, INK if kept != null else DIM))
	return panel


func _level_note(power: PowerData, level: int) -> String:
	if power == null:
		return ""
	if level == PowerRules.UPGRADE_LEVELS[0]:
		return "Level 3: %s" % power.level3_text
	if level == PowerRules.UPGRADE_LEVELS[1]:
		return "Level 5: %s" % power.level5_text
	return "Level %d: +%d%% power damage." % [level, roundi(balance.power_damage_per_level * 100.0)]


func _power(power_id: StringName) -> PowerData:
	return ContentDB.get_item(&"powers", power_id) as PowerData


func _name(power_id: StringName) -> String:
	var power: PowerData = _power(power_id)
	return power.display_name if power != null else String(power_id).capitalize()


func _row(node_name: String, gap: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = node_name
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", gap)
	return row


func _clear(row: Node) -> void:
	for child: Node in row.get_children():
		row.remove_child(child)
		child.queue_free()


func _box(fill: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(5)
	return style


func _place(node: Control, at: Vector2, size_px: Vector2) -> void:
	node.position = at
	node.size = size_px
	if node is Label:
		(node as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(node)


func _label(text: String, font_size: int, color: Color, node_name: String = "") -> Label:
	var label: Label = Label.new()
	if not node_name.is_empty():
		label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
