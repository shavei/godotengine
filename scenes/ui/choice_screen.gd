class_name ChoiceScreen
extends Control
## The Choice screen (docs/GDD.md Section 3.1), opened at the village Shrine. Settles the
## hero's power offer (HeroState.power_offer): first take one orb if none was taken in
## the boss room, then Keep it in a free slot, Merge it into the same kept power
## (+1 level), Give it to a villager forever, or leave it behind. With every slot full a
## kept power can be given away to make room (or, when every villager holds a power
## already, let go). With no offer waiting, a kept power can be given away at any time.
## Plain words (ChoiceText, after the owner found the Choice confusing): beside the power
## sit "If you keep it" and "If you give it" panels; villager cards show the gift's
## timeline (now, Adept in N runs, Master in N runs and the Technique they will teach);
## each button says under the row what pressing it does; a "How the Choice works" card
## opens by itself the first time (ProfileState.choice_help_seen) and from How it works.
## Giving, letting go and leaving ask for a second press.
## "Grow stronger" opens the Shrine's GrowthPanel: attribute points, power levels, respec.
## The first power ever earned must be given, to the villager FirstGift names (the Elder
## asks for it): only that card is open and Keep, Merge and Leave are not offered. After a
## gift the screen goes back to the village, where the gift ceremony plays.
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
const HOW: StringName = &"how"
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
## Go back to the village for the ceremony as soon as a gift is given (tests turn it off).
var leave_after_gift: bool = true
## The gift the village's ceremony plays ({villager_id, power_id, first_gift}), or empty.
var ceremony: Dictionary = {}

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
## The "How the Choice works" card, while it shows.
var help_card: PanelContainer
## When the screen opened, and when the waiting power first showed (-1 before), in
## msec: how long a Choice took (metrics, EventBus.choice_made).
var _opened_msec: int = 0
var _waiting_since_msec: int = -1


func _ready() -> void:
	player_id = int(SceneRouter.context.get("player_id", GameState.LOCAL_PLAYER_ID))
	hero = GameState.hero_state(player_id)
	village = GameState.profile.village
	balance = ContentDB.get_item(&"balance", &"default") as BalanceData
	if balance == null:
		balance = BalanceData.new()
	_opened_msec = Time.get_ticks_msec()
	_build()
	refresh()


func _unhandled_input(event: InputEvent) -> void:
	# Leaving early is safe: an unsettled offer waits in the save (the Shrine keeps glowing).
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		if help_card != null:
			close_help()
		else:
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
	if _waiting_since_msec < 0 and not done and PowerOffer.waiting_power(hero) != &"":
		_waiting_since_msec = Time.get_ticks_msec()
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
		_add_action("Continue", &"continue", "ContinueButton", &"", ChoiceText.DONE_HINT)
		_add_grow_action()
	elif _view == VIEW_VILLAGERS:
		_show_villagers()
	elif _view == VIEW_KEPT:
		_show_kept_to_give()
	elif PowerOffer.is_picking(hero):
		_show_pick()
	elif PowerOffer.waiting_power(hero) != &"" and _first_gift_active():
		_show_first_gift(PowerOffer.waiting_power(hero))
		_help_once()
	elif PowerOffer.waiting_power(hero) != &"":
		_show_decision(PowerOffer.waiting_power(hero))
		_help_once()
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
	var slot: int = hero.kept_powers.size() + 1
	var button_name: String = InputBindings.hint_for(StringName("power_%d" % slot), InputBindings.active_kind)
	_note.text = ""
	match PowerOffer.choice_for(hero, power_id, balance):
		PowerOffer.KEEP:
			_subline.text = "Keep it in a free slot, or give it to a villager forever." if can_give \
					else "Keep it in a free slot, or leave it behind."
			_cards.add_child(_info_panel("If you keep it", ChoiceText.keep_lines(slot, button_name,
					PowerRules.cooldown(power, hero.attribute(HeroState.FOCUS), balance)), GOLD, "KeepPanel"))
			_add_action("Keep it (slot %d)" % slot, PowerOffer.KEEP, "KeepButton", &"",
					ChoiceText.keep_hint(_name(power_id), slot, button_name))
		PowerOffer.MERGE:
			_subline.text = "You keep %s already. Merge them for a level." % _name(power_id)
			_cards.add_child(_info_panel("If you merge it", ChoiceText.merge_lines(_name(power_id), kept.level + 1,
					_level_note(power, kept.level + 1)), GOLD, "KeepPanel"))
			_add_action("Merge: level %d > %d" % [kept.level, kept.level + 1], PowerOffer.MERGE, "MergeButton", &"",
					ChoiceText.merge_hint(_name(power_id), kept.level + 1))
		PowerOffer.MAXED:
			_subline.text = "Your %s is at its highest level already." % _name(power_id)
			_cards.add_child(_info_panel("If you keep it", ["Your %s is at level %d already: merging adds nothing." % [
					_name(power_id), kept.level]] as PackedStringArray, GOLD, "KeepPanel"))
		PowerOffer.REPLACE:
			_cards.add_child(_info_panel("If you keep it", ["Every slot is full.",
					"Give a kept power away (it keeps its level) or let one go, and this one takes its slot."] as PackedStringArray,
					GOLD, "KeepPanel"))
			if can_give:
				_subline.text = "Every slot is full. Give one power away to make room, or leave this one."
				_add_action("Give a kept power away", GIVE_KEPT, "GiveKeptButton", &"", ChoiceText.give_kept_hint(_name(power_id)))
			else:
				_subline.text = "Every slot is full. Let a kept power go to make room, or leave this one."
				for other: KeptPower in hero.kept_powers:
					_add_action("Let %s go (lv %d)" % [_name(other.power_id), other.level], PowerOffer.REPLACE,
							"Let%sGoButton" % String(other.power_id).capitalize(), other.power_id,
							ChoiceText.let_go_hint(_name(other.power_id), _name(power_id)))
	_cards.move_child(card, _cards.get_child_count() - 1)
	if can_give:
		_cards.add_child(_info_panel("If you give it", ChoiceText.give_lines(balance), GOOD, "GivePanel"))
		_add_action("Give to a villager", GIVE, "GiveButton", power_id, ChoiceText.give_hint(_name(power_id)))
	else:
		_cards.add_child(_info_panel("If you give it", ["Every villager holds a power already.",
				"More villagers move in as your Renown grows."] as PackedStringArray, DIM, "GivePanel"))
	_add_action("Leave it behind", LEAVE, "LeaveButton", &"", ChoiceText.leave_hint(_name(power_id)))
	_add_grow_action()
	_add_how_action()


## The first power must be given: the Elder asks for it to go to one villager.
func _show_first_gift(power_id: StringName) -> void:
	var power: PowerData = _power(power_id)
	var who: VillagerData = _villager(village.villagers[_forced_villager()].villager_id)
	_headline.text = "Your first Spark: %s" % _name(power_id)
	_subline.text = "The Elder: \"A Spark grows when it is shared. Give this one to %s.\"" % who.title()
	var card: PanelContainer = PanelContainer.new()
	card.name = "%sCard" % String(power_id).capitalize()
	card.custom_minimum_size = CARD_SIZE
	card.add_theme_stylebox_override("panel", _box(PANEL, power.color if power != null else INK))
	_cards.add_child(_info_panel("If you keep it", ["Not this time: your first Spark is always a gift.",
			"From the next power on, you choose: keep it, give it or merge it."] as PackedStringArray, GOLD, "KeepPanel"))
	_fill_card(card, power_id)
	_cards.add_child(card)
	_cards.add_child(_info_panel("If you give it", ChoiceText.give_lines(balance), GOOD, "GivePanel"))
	_note.text = ""
	_add_action("Give to %s" % who.title(), GIVE, "GiveButton", power_id,
			"Give: see what %s would do with it, then give it. It is theirs forever." % who.title())
	_add_grow_action()
	_add_how_action()


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
	_add_action("Continue", &"continue", "ContinueButton", &"", ChoiceText.DONE_HINT)
	_add_grow_action()


## "Grow stronger" (it glows in gold while something waits to be spent).
func _add_grow_action() -> void:
	var button: Button = _add_action("Grow stronger", GROW, "GrowButton", &"", ChoiceText.GROW_HINT)
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
	_add_action("Back", BACK, "BackButton", &"", ChoiceText.BACK_HINT)
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
	_add_action("Back", BACK, "BackButton", &"", ChoiceText.BACK_HINT)


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
	if _first_gift_active():
		_subline.text = "The Elder asks for this one to go to %s." % _villager(village.villagers[_forced_villager()].villager_id).title()
	var order: Array[VillagerState] = village.villagers.duplicate()
	order.sort_custom(func(a: VillagerState, b: VillagerState) -> bool: return a.plot < b.plot)
	for villager: VillagerState in order:
		_cards.add_child(_villager_card(villager, level))
	_add_action("Back", BACK, "BackButton", &"", ChoiceText.BACK_HINT)


func _villager_card(villager: VillagerState, level: int) -> Button:
	var data: VillagerData = _villager(villager.villager_id)
	var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(villager.villager_id, _giving)) as ComboData
	var tint: Color = data.color if data != null else INK
	var card: Button = Button.new()
	card.name = "%sCard" % String(villager.villager_id).capitalize()
	card.custom_minimum_size = VILLAGER_CARD_SIZE
	var index: int = village.villagers.find(villager)
	card.disabled = villager.has_power() or not FirstGift.allows(GameState.profile, balance, index)
	card.add_theme_stylebox_override("normal", _box(PANEL, tint.darkened(0.45)))
	card.add_theme_stylebox_override("hover", _box(PANEL.lightened(0.05), tint))
	card.add_theme_stylebox_override("pressed", _box(PANEL.lightened(0.1), tint))
	card.add_theme_stylebox_override("disabled", _box(PANEL.darkened(0.35), DIM.darkened(0.5)))
	var focus: StyleBoxFlat = _box(Color.TRANSPARENT, tint.lightened(0.3))
	focus.set_border_width_all(2)
	card.add_theme_stylebox_override("focus", focus)
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
	if card.disabled:
		column.add_child(_card_text("The Elder asks for someone else this time.", DIM, "Rule"))
		return card
	if combo == null:
		column.add_child(_card_text("No service for %s yet." % _name(_giving), DIM, "Novice"))
		return card
	var points: int = GiftSystem.starting_tp(level)
	var steps: PackedStringArray = ChoiceText.timeline(combo, points, balance)
	var step_names: Array[String] = ["Novice", "Adept", "Master"]
	var step_colors: Array[Color] = [INK, DIM, GOLD]
	for i: int in steps.size():
		column.add_child(_card_text(steps[i], step_colors[i], step_names[i]))
	if combo.novice.price > 0:
		column.add_child(_card_text("Bought once at the %s: %d coins." % [data.workplace if data != null else "shop", combo.novice.price], GOLD, "Price"))
	elif combo.novice.only_in_raids():
		column.add_child(_card_text("Works in raids, which have not started yet.", GOLD, "Raids"))
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
	if _first_gift_active():
		return false
	var power_id: StringName = PowerOffer.waiting_power(hero)
	var kept: KeptPower = GiftSystem.keep(hero, power_id, balance, GameState.profile.run_count)
	if kept == null:
		return false
	EventBus.power_kept.emit(player_id, power_id)
	_log_choice(MetricsLog.KEEP, power_id, kept.level)
	_settle("%s is kept in slot %d." % [_name(power_id), hero.kept_powers.size()])
	return true


## Merges the waiting power into the same kept power (+1 level).
func merge() -> bool:
	if _first_gift_active():
		return false
	var power_id: StringName = PowerOffer.waiting_power(hero)
	var new_level: int = GiftSystem.merge(hero, power_id, balance, GameState.profile.run_count)
	if new_level == 0:
		return false
	EventBus.power_merged.emit(player_id, power_id, new_level)
	_log_choice(MetricsLog.MERGE, power_id, new_level)
	_settle("%s merged: now level %d." % [_name(power_id), new_level])
	return true


## Lets `old_id` go; the waiting power takes its slot at level 1.
func replace(old_id: StringName) -> bool:
	if _first_gift_active():
		return false
	var power_id: StringName = PowerOffer.waiting_power(hero)
	if PowerOffer.choice_for(hero, power_id, balance) != PowerOffer.REPLACE:
		return false
	var slot: int = hero.kept_powers.find(GiftSystem.find(hero, old_id))
	if GiftSystem.replace(hero, old_id, power_id, GameState.profile.run_count) == null:
		return false
	EventBus.power_kept.emit(player_id, power_id)
	_log_choice(MetricsLog.REPLACE, power_id, 1, &"", old_id)
	_settle("%s is gone. %s is kept in slot %d." % [_name(old_id), _name(power_id), slot + 1])
	return true


## Leaves the waiting power behind.
func leave() -> void:
	if _first_gift_active():
		return
	var power_id: StringName = PowerOffer.waiting_power(hero)
	var kept: KeptPower = GiftSystem.find(hero, power_id)
	_log_choice(MetricsLog.LEAVE, power_id, kept.level if kept != null else 1)
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
	if not FirstGift.allows(GameState.profile, balance, villager_index):
		return false
	var first_gift: bool = _first_gift_active()
	var waiting: StringName = PowerOffer.waiting_power(hero)
	var run_number: int = GameState.profile.run_count
	var level: int = _giving_level()
	var villager: VillagerState
	if not _giving_kept:
		villager = GiftSystem.give(village, villager_index, _giving, 1)
	elif waiting != &"" and not PowerOffer.is_picking(hero):
		villager = GiftSystem.give_kept_to_make_room(village, hero, _giving, waiting, villager_index, run_number)
	else:
		villager = GiftSystem.give_kept(village, hero, _giving, villager_index)
	if villager == null:
		return false
	FirstGift.complete(GameState.profile)
	ceremony = {"villager_id": villager.villager_id, "power_id": _giving, "first_gift": first_gift}
	EventBus.power_given.emit(player_id, _giving, villager_index)
	if _giving_kept:
		_log_choice(MetricsLog.GIVE_KEPT, _giving, level, villager.villager_id, waiting)
	else:
		_log_choice(MetricsLog.GIVE, _giving, level, villager.villager_id, &"", first_gift)
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
	if leave_after_gift:
		continue_on()
	return true


## Back to the village, beside the Shrine; a gift just given plays its ceremony there.
func continue_on() -> void:
	var context: Dictionary = {"player_id": player_id, "from": "shrine"}
	if not ceremony.is_empty():
		context["ceremony"] = ceremony
	SceneRouter.go(VILLAGE_SCENE, context)


func _settle(message: String, note: String = "") -> void:
	PowerOffer.clear(hero)
	_finish(message, note)


func _finish(message: String, note: String = "") -> void:
	done = true
	_done_message = message
	_save()
	refresh()
	_note.text = note


## Tells EventBus (and so the metrics log) what the Choice was and how long it took.
func _log_choice(action: String, power_id: StringName, level: int, villager_id: StringName = &"",
		other_power: StringName = &"", first_gift: bool = false) -> void:
	var since: int = _waiting_since_msec if _waiting_since_msec >= 0 else _opened_msec
	var seconds: float = (Time.get_ticks_msec() - since) / 1000.0
	EventBus.choice_made.emit(player_id, MetricsLog.choice_record(action, power_id, level, seconds,
			GameState.profile.run_count, villager_id, other_power, first_gift))


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
		HOW:
			show_help()
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


func _add_action(text: String, action: StringName, node_name: String, power_id: StringName = &"",
		hint: String = "") -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	button.set_meta(&"text", text)
	if not hint.is_empty():
		# What pressing it does, under the row while it has focus (or the mouse is on it).
		button.set_meta(&"hint", hint)
		button.focus_entered.connect(func() -> void: _note.text = hint)
		button.mouse_entered.connect(func() -> void: _note.text = hint)
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


## A card-sized panel beside the power: a heading and a few plain lines.
func _info_panel(title: String, lines: PackedStringArray, color: Color, node_name: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = CARD_SIZE
	panel.add_theme_stylebox_override("panel", _box(PANEL.darkened(0.2), color.darkened(0.35)))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	column.add_child(_label(title, 10, color, "Title"))
	for line: String in lines:
		var label: Label = _label(line, 8, INK, "Line")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.custom_minimum_size = Vector2(CARD_SIZE.x - 12, 0)
		column.add_child(label)
	return panel


## The first real Choice opens the "How the Choice works" card by itself, once.
func _help_once() -> void:
	if not GameState.profile.choice_help_seen:
		show_help.call_deferred()


func _add_how_action() -> void:
	_add_action("How it works", HOW, "HowButton", &"", ChoiceText.HOW_HINT)


## The "How the Choice works" card over the screen; Got it closes it.
func show_help() -> void:
	if help_card != null:
		return
	GameState.profile.choice_help_seen = true
	_save()
	help_card = PanelContainer.new()
	help_card.name = "HelpCard"
	help_card.add_theme_stylebox_override("panel", _box(PANEL, GOLD))
	help_card.position = Vector2(110, 70)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	help_card.add_child(column)
	column.add_child(_label(ChoiceText.HOW_TITLE, 13, GOLD, "Title"))
	for line: String in ChoiceText.HOW_LINES:
		var label: Label = _label(line, 9, INK, "Line")
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size = Vector2(400, 0)
		column.add_child(label)
	var close: Button = Button.new()
	close.name = "GotItButton"
	close.text = "Got it"
	close.add_theme_font_size_override("font_size", 9)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.custom_minimum_size = Vector2(100, 24)
	close.pressed.connect(close_help)
	column.add_child(close)
	add_child(help_card)
	# As tall as its lines, centred on the screen.
	help_card.reset_size()
	help_card.position.y = roundf((360.0 - help_card.size.y) * 0.5)
	close.grab_focus()


func close_help() -> void:
	if help_card == null:
		return
	help_card.queue_free()
	help_card = null
	_focus_first()


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


func _first_gift_active() -> bool:
	return FirstGift.is_active(GameState.profile, balance)


func _forced_villager() -> int:
	return FirstGift.villager_index(GameState.profile, balance)


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
