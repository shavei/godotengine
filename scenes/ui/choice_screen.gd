class_name ChoiceScreen
extends Control
## The Choice screen (docs/GDD.md Section 3.1), opened at the village Shrine. Settles the
## hero's power offer (HeroState.power_offer): first take one orb if none was taken in
## the boss room, then Keep it in a free slot, Merge it into the same kept power
## (+1 level), Give it to a villager forever, or leave it behind. With every slot full a
## kept power can be given away to make room (or, when every villager holds a power
## already, let go). With no offer waiting, a kept power can be given away at any time.
## Villager cards preview the Novice and Adept services; the Technique shows as "???"
## until the Codex exists. Giving, letting go and leaving ask for a second press.
## "Grow stronger" opens the Shrine's GrowthPanel: attribute points, power levels, respec.
## Reads SceneRouter.context["player_id"] (the local hero by default).

const VILLAGE_SCENE: String = "res://scenes/village/village.tscn"
const GOLD: Color = Color(1, 0.78, 0.45)
const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.72, 0.67, 0.6)
const WARN: Color = Color(0.95, 0.5, 0.45)
const GOOD: Color = Color(0.6, 0.95, 0.55)
const PANEL: Color = Color(0.2, 0.16, 0.13)
const CARD_SIZE: Vector2 = Vector2(190, 118)
const VILLAGER_CARD_SIZE: Vector2 = Vector2(140, 176)
const SLOT_SIZE: Vector2 = Vector2(150, 34)
const LEAVE: StringName = &"leave"
const GIVE: StringName = &"give"
const GIVE_KEPT: StringName = &"give_kept"
const BACK: StringName = &"back"
const GROW: StringName = &"grow"
## Screen views beside the offer itself: pick a villager, or pick a kept power to give.
const VIEW_OFFER: StringName = &"offer"
const VIEW_VILLAGERS: StringName = &"villagers"
const VIEW_KEPT: StringName = &"kept"
const VIEW_GROW: StringName = &"grow"

var player_id: int = GameState.LOCAL_PLAYER_ID
var hero: HeroState
var village: VillageState
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
var _slots_heading: Label
## The button that asked "Sure?" and waits for a second press, or null.
var _armed: Button
var _view: StringName = VIEW_OFFER
## The power being given, and whether it comes out of a kept slot.
var _giving: StringName = &""
var _giving_kept: bool = false
## What the settled Choice did (the headline's subline once done).
var _done_message: String = ""
## The Grow stronger view's panel, while it shows.
var growth: GrowthPanel


func _ready() -> void:
	player_id = int(SceneRouter.context.get("player_id", GameState.LOCAL_PLAYER_ID))
	hero = GameState.hero_state(player_id)
	village = GameState.profile.village
	balance = ContentDB.get_item(&"balance", &"default") as BalanceData
	if balance == null:
		balance = BalanceData.new()
	_build()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	# Leaving early is safe: an unsettled offer waits in the save (the Shrine keeps glowing).
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
	_slots_heading = _label("Your powers", 9, DIM, "SlotsHeading")
	_place(_slots_heading, Vector2(0, 182), Vector2(640, 14))
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
	if growth != null:
		remove_child(growth)
		growth.queue_free()
		growth = null
	for i: int in GiftSystem.slot_count(balance):
		_slots.add_child(_slot_view(hero.kept_powers[i] if i < hero.kept_powers.size() else null))
	# Villager cards and the growth panel are tall and cover the slot row.
	_slots.visible = _view == VIEW_OFFER or _view == VIEW_KEPT or (done and _view != VIEW_GROW)
	_slots_heading.visible = _slots.visible
	if _view == VIEW_GROW:
		_show_growth()
		return
	if done:
		_headline.text = "The Choice is made"
		_subline.text = _done_message
		_add_action("Continue", &"continue", "ContinueButton")
		_add_grow_action()
	elif _view == VIEW_VILLAGERS:
		_show_villagers()
	elif _view == VIEW_KEPT:
		_show_kept_to_give()
	elif PowerOffer.is_picking(hero):
		_show_pick()
	elif PowerOffer.waiting_power(hero) != &"":
		_show_decision(PowerOffer.waiting_power(hero))
	else:
		_show_shrine()
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
	var can_give: bool = not GiftSystem.open_villagers(village).is_empty()
	match PowerOffer.choice_for(hero, power_id, balance):
		PowerOffer.KEEP:
			_subline.text = "Keep it in a free slot, or give it to a villager forever." if can_give \
					else "Keep it in a free slot, or leave it behind."
			_add_action("Keep it (slot %d)" % (hero.kept_powers.size() + 1), PowerOffer.KEEP, "KeepButton")
			_note.text = "Kept powers go on the Power buttons in your next run. A villager trains a gift and serves the village with it."
		PowerOffer.MERGE:
			_subline.text = "You keep %s already. Merge them for a level." % _name(power_id)
			_add_action("Merge: level %d > %d" % [kept.level, kept.level + 1], PowerOffer.MERGE, "MergeButton")
			_note.text = _level_note(power, kept.level + 1)
		PowerOffer.MAXED:
			_subline.text = "Your %s is at its highest level already." % _name(power_id)
			_note.text = "There is nothing to merge. A villager can still use it." if can_give else "There is nothing to merge."
		PowerOffer.REPLACE:
			if can_give:
				_subline.text = "Every slot is full. Give one power away to make room, or leave this one."
				_add_action("Give a kept power away", GIVE_KEPT, "GiveKeptButton")
				_note.text = "A kept power you give away keeps its level: the villager starts training ahead. %s takes its slot." % _name(power_id)
			else:
				_subline.text = "Every slot is full. Let a kept power go to make room, or leave this one."
				for other: KeptPower in hero.kept_powers:
					_add_action("Let %s go (lv %d)" % [_name(other.power_id), other.level], PowerOffer.REPLACE,
							"Let%sGoButton" % String(other.power_id).capitalize(), other.power_id)
				_note.text = "Every villager holds a power already. A power you let go is gone, with the shards spent on it."
	if can_give:
		_add_action("Give to a villager", GIVE, "GiveButton", power_id)
	_add_action("Leave it behind", LEAVE, "LeaveButton")
	_add_grow_action()


## No offer waits: the Shrine still lets the hero give a kept power away.
func _show_shrine() -> void:
	_headline.text = "No power is waiting"
	var can_give: bool = not GiftSystem.open_villagers(village).is_empty()
	if hero.kept_powers.is_empty() or not can_give:
		_subline.text = "Clear a region's boss to earn one."
		_note.text = ""
	else:
		_subline.text = "You can give a kept power to a villager here, at any time."
		_note.text = "A kept power you give away keeps its level: the villager starts training ahead."
		_add_kept_gift_actions()
	_add_action("Continue", &"continue", "ContinueButton")
	_add_grow_action()


## "Grow stronger" (it glows in gold while something waits to be spent).
func _add_grow_action() -> void:
	var button: Button = _add_action("Grow stronger", GROW, "GrowButton")
	if GrowthPanel.has_anything_to_spend(hero, balance):
		button.add_theme_color_override("font_color", GOLD)
		button.add_theme_color_override("font_focus_color", GOLD)


## The Shrine's growth: attribute points, power levels and respec.
func _show_growth() -> void:
	_headline.text = "Grow stronger"
	_subline.text = "Spend attribute points and Power Shards. Kept powers level up here."
	_note.text = ""
	growth = GrowthPanel.new()
	growth.setup(player_id, balance)
	growth.save_on_spend = save_on_change
	growth.changed.connect(_on_growth_changed)
	growth.position = Vector2(20, 60)
	growth.size = Vector2(600, 180)
	add_child(growth)
	_add_action("Back", BACK, "BackButton")
	var first: Button = growth.default_focus()
	if first != null and get_viewport() != null:
		first.grab_focus()
	else:
		_focus_first()


## Focus moves on when a spent button can no longer be pressed.
func _on_growth_changed() -> void:
	if get_viewport() == null:
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null or (focused is Button and (focused as Button).disabled):
		var first: Button = growth.default_focus()
		if first != null:
			first.grab_focus()
		else:
			_focus_first()


## Every slot is full (or the Shrine with no offer): which kept power goes?
func _show_kept_to_give() -> void:
	var waiting: StringName = PowerOffer.waiting_power(hero)
	_headline.text = "Give a kept power away"
	_subline.text = "%s takes its slot at level 1." % _name(waiting) if waiting != &"" else "Pick the power to give."
	_note.text = "It keeps its level: the villager starts with that many Training Points, less one."
	_add_kept_gift_actions()
	_add_action("Back", BACK, "BackButton")


func _add_kept_gift_actions() -> void:
	for kept: KeptPower in hero.kept_powers:
		_add_action("Give %s (lv %d)" % [_name(kept.power_id), kept.level], GIVE_KEPT,
				"Give%sButton" % String(kept.power_id).capitalize(), kept.power_id)


## One card per villager: who they are and what the power would make of their service.
func _show_villagers() -> void:
	var level: int = _giving_level()
	_headline.text = "Give %s to a villager" % _name(_giving)
	_subline.text = "Gifts are forever. They train it, and it comes back to you as a Technique."
	_note.text = "Pick a villager, then press again to give."
	var order: Array[VillagerState] = village.villagers.duplicate()
	order.sort_custom(func(a: VillagerState, b: VillagerState) -> bool: return a.plot < b.plot)
	for villager: VillagerState in order:
		_cards.add_child(_villager_card(villager, level))
	_add_action("Back", BACK, "BackButton")


func _villager_card(villager: VillagerState, level: int) -> Button:
	var data: VillagerData = _villager(villager.villager_id)
	var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(villager.villager_id, _giving)) as ComboData
	var tint: Color = data.color if data != null else INK
	var card: Button = Button.new()
	card.name = "%sCard" % String(villager.villager_id).capitalize()
	card.custom_minimum_size = VILLAGER_CARD_SIZE
	card.disabled = villager.has_power()
	card.add_theme_stylebox_override("normal", _box(PANEL, tint.darkened(0.45)))
	card.add_theme_stylebox_override("hover", _box(PANEL.lightened(0.05), tint))
	card.add_theme_stylebox_override("pressed", _box(PANEL.lightened(0.1), tint))
	card.add_theme_stylebox_override("disabled", _box(PANEL.darkened(0.35), DIM.darkened(0.5)))
	var focus: StyleBoxFlat = _box(Color.TRANSPARENT, tint.lightened(0.3))
	focus.set_border_width_all(2)
	card.add_theme_stylebox_override("focus", focus)
	var index: int = village.villagers.find(villager)
	card.pressed.connect(func() -> void: _on_villager_pressed(card, index))
	var column: VBoxContainer = VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	column.add_child(_label(data.display_name if data != null else String(villager.villager_id), 11, tint, "Name"))
	column.add_child(_label("the %s" % data.job_name if data != null else "", 8, DIM, "Job"))
	if villager.has_power():
		var rank: int = TrainingSystem.rank(villager, balance)
		column.add_child(_card_text("Holds %s (%s)." % [_name(villager.power_id), TrainingSystem.rank_name(rank)], INK, "Holds"))
		column.add_child(_card_text("One power each, for good.", DIM, "Rule"))
		return card
	if combo == null:
		column.add_child(_card_text("No service for %s yet." % _name(_giving), DIM, "Novice"))
		return card
	column.add_child(_card_text("Novice: %s" % combo.novice.description, INK, "Novice"))
	column.add_child(_card_text("Adept: %s" % combo.adept.description, DIM, "Adept"))
	column.add_child(_card_text("Master: ???", DIM, "Master"))
	if combo.novice.price > 0:
		column.add_child(_card_text("Bought once at the %s: %d coins." % [data.workplace if data != null else "shop", combo.novice.price], GOLD, "Price"))
	elif combo.novice.only_in_raids():
		column.add_child(_card_text("Works in raids, which have not started yet.", GOLD, "Raids"))
	var points: int = GiftSystem.starting_tp(level)
	if points > 0:
		var rank_text: String = TrainingSystem.rank_name(TrainingSystem.rank_for_points(points, balance))
		column.add_child(_card_text("Starts at %d TP (%s)." % [points, rank_text], GOOD, "Start"))
	return card


func _card_text(text: String, color: Color, node_name: String) -> Label:
	var label: Label = _label(text, 7, color, node_name)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(VILLAGER_CARD_SIZE.x - 12, 0)
	return label


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


## Opens the villager cards for the waiting power (or, with `from_slot`, a kept power).
func start_give(power_id: StringName, from_slot: bool) -> void:
	_giving = power_id
	_giving_kept = from_slot
	_view = VIEW_VILLAGERS
	refresh()


## Gives the power being given to the villager at `villager_index`, for good. A kept
## power given while an offer waits makes room: the new power takes its slot.
func give(villager_index: int) -> bool:
	var waiting: StringName = PowerOffer.waiting_power(hero)
	var run_number: int = GameState.profile.run_count
	var villager: VillagerState
	if not _giving_kept:
		villager = GiftSystem.give(village, villager_index, _giving, 1)
	elif waiting != &"" and not PowerOffer.is_picking(hero):
		villager = GiftSystem.give_kept_to_make_room(village, hero, _giving, waiting, villager_index, run_number)
	else:
		villager = GiftSystem.give_kept(village, hero, _giving, villager_index)
	if villager == null:
		return false
	EventBus.power_given.emit(player_id, _giving, villager_index)
	var data: VillagerData = _villager(villager.villager_id)
	var who: String = data.title() if data != null else String(villager.villager_id)
	var message: String = "%s now holds %s." % [who, _name(_giving)]
	if _giving_kept and waiting != &"":
		EventBus.power_kept.emit(player_id, waiting)
		message += " %s takes its slot." % _name(waiting)
	var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(villager.villager_id, _giving)) as ComboData
	var line: String = "\"%s\"" % combo.gift_line if combo != null and not combo.gift_line.is_empty() else ""
	_view = VIEW_OFFER
	if _giving_kept and waiting == &"":
		_finish(message, line)
	else:
		_settle(message, line)
	return true


func continue_on() -> void:
	SceneRouter.go(VILLAGE_SCENE)


func _settle(message: String, note: String = "") -> void:
	PowerOffer.clear(hero)
	_finish(message, note)


func _finish(message: String, note: String = "") -> void:
	done = true
	_done_message = message
	_save()
	refresh()
	_note.text = note


func _save() -> void:
	if save_on_change:
		GameState.save_profile()


## Keep and Merge act at once; letting go and leaving ask "Sure?" first.
func _on_action(action: StringName, button: Button, power_id: StringName) -> void:
	match action:
		&"continue":
			continue_on()
		BACK:
			_view = VIEW_OFFER
			refresh()
		GROW:
			_view = VIEW_GROW
			refresh()
		GIVE:
			start_give(power_id, false)
		GIVE_KEPT:
			if power_id == &"":
				_view = VIEW_KEPT
				refresh()
			else:
				start_give(power_id, true)
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


## First press on a villager card arms it, the second gives the power.
func _on_villager_pressed(card: Button, villager_index: int) -> void:
	if _armed == card:
		give(villager_index)
		return
	_arm(card, "")
	var data: VillagerData = _villager(village.villagers[villager_index].villager_id)
	_note.text = "Press again to give %s to %s. It is theirs forever." % [_name(_giving), data.title() if data != null else "them"]


func _arm(button: Button, question: String) -> void:
	if _armed != null and _armed.has_meta(&"text"):
		_armed.text = _armed.get_meta(&"text")
	_armed = button
	if not question.is_empty():
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
			if child is Button and not child.is_queued_for_deletion() and not (child as Button).disabled:
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


func _giving_level() -> int:
	var kept: KeptPower = GiftSystem.find(hero, _giving) if _giving_kept else null
	return kept.level if kept != null else 1


func _villager(villager_id: StringName) -> VillagerData:
	return ContentDB.get_item(&"villagers", villager_id) as VillagerData


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
