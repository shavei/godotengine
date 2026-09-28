extends GutTest
## The Choice screen: take one orb, then keep, merge, give to a villager, give a kept
## power away to make room (or let it go when no villager is free), or leave the new
## power behind. With no offer, the Shrine gives kept powers away.

const CHOICE_SCENE: PackedScene = preload("res://scenes/ui/choice_screen.tscn")

var _original_profile: ProfileState
var _original_context: Dictionary
var hero: HeroState


func before_each() -> void:
	_original_profile = GameState.profile
	_original_context = SceneRouter.context
	GameState.new_profile()
	# Past the forced first gift (its tests set this back).
	GameState.profile.first_gift_done = true
	hero = GameState.hero_state(GameState.LOCAL_PLAYER_ID)


func after_each() -> void:
	GameState.profile = _original_profile
	SceneRouter.context = _original_context


func _open() -> ChoiceScreen:
	SceneRouter.context = {"player_id": GameState.LOCAL_PLAYER_ID}
	var screen: ChoiceScreen = CHOICE_SCENE.instantiate()
	screen.save_on_change = false
	screen.leave_after_gift = false
	add_child_autofree(screen)
	await wait_process_frames(1)
	return screen


func _button(screen: ChoiceScreen, node_name: String) -> Button:
	var node: Node = screen.find_child(node_name, true, false)
	return node as Button if node != null and not node.is_queued_for_deletion() else null


func _text(screen: ChoiceScreen, node_name: String) -> String:
	return (screen.find_child(node_name, true, false) as Label).text


func _village() -> VillageState:
	return GameState.profile.village


## Every villager holds a power, so nobody can take a gift.
func _fill_villagers() -> void:
	for villager: VillagerState in _village().villagers:
		villager.power_id = &"stone"


func _ids() -> Array:
	return hero.kept_powers.map(func(k: KeptPower) -> StringName: return k.power_id)


func test_two_orbs_ask_to_take_one_first() -> void:
	hero.power_offer = [&"fire", &"stone"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_eq(_text(screen, "Headline"), "2 Sparks broke free")
	var fire: Button = _button(screen, "FireCard")
	assert_not_null(fire)
	assert_not_null(_button(screen, "StoneCard"))
	assert_eq(screen.get_viewport().gui_get_focus_owner(), fire, "a card has focus for the gamepad")
	fire.pressed.emit()
	await wait_process_frames(1)
	assert_eq(hero.power_offer, [&"fire"] as Array[StringName])
	assert_eq(_text(screen, "Headline"), "A new power: Fire")
	assert_not_null(_button(screen, "KeepButton"))


func test_keep_puts_the_power_in_a_free_slot() -> void:
	hero.power_offer = [&"frost"] as Array[StringName]
	watch_signals(EventBus)
	var screen: ChoiceScreen = await _open()
	_button(screen, "KeepButton").pressed.emit()
	await wait_process_frames(1)
	assert_eq(_ids(), [&"frost"])
	assert_true(hero.power_offer.is_empty())
	assert_signal_emitted_with_parameters(EventBus, "power_kept", [0, &"frost"])
	assert_true(screen.done)
	assert_eq(_text(screen, "Subline"), "Frost is kept in slot 1.")
	assert_not_null(_button(screen, "ContinueButton"))
	assert_null(_button(screen, "KeepButton"))


func test_merge_raises_the_kept_power() -> void:
	hero.kept_powers.append(KeptPower.create(&"stone", 2))
	hero.power_offer = [&"stone"] as Array[StringName]
	watch_signals(EventBus)
	var screen: ChoiceScreen = await _open()
	assert_null(_button(screen, "KeepButton"))
	var merge: Button = _button(screen, "MergeButton")
	assert_eq(merge.text, "Merge: level 2 > 3")
	assert_true(_text(screen, "Note").begins_with("Level 3:"), "shows the upgrade it unlocks")
	merge.pressed.emit()
	await wait_process_frames(1)
	assert_eq(hero.kept_powers[0].level, 3)
	assert_signal_emitted_with_parameters(EventBus, "power_merged", [0, &"stone", 3])
	assert_true(hero.power_offer.is_empty())


func test_full_slots_let_a_kept_power_go_after_a_second_press() -> void:
	_fill_villagers()
	for id: StringName in [&"fire", &"frost", &"stone"]:
		hero.kept_powers.append(KeptPower.create(id, 2))
	hero.power_offer = [&"growth"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_null(_button(screen, "KeepButton"))
	var let_go: Button = _button(screen, "LetFrostGoButton")
	assert_eq(let_go.text, "Let Frost go (lv 2)")
	let_go.pressed.emit()
	assert_eq(let_go.text, "Sure? Frost is lost")
	assert_eq(_ids(), [&"fire", &"frost", &"stone"], "nothing happens on the first press")
	let_go.pressed.emit()
	await wait_process_frames(1)
	assert_eq(_ids(), [&"fire", &"growth", &"stone"], "Growth takes Frost's slot")
	assert_eq(hero.kept_powers[1].level, 1)
	assert_true(hero.power_offer.is_empty())


func test_arming_another_button_disarms_the_first() -> void:
	_fill_villagers()
	for id: StringName in [&"fire", &"frost", &"stone"]:
		hero.kept_powers.append(KeptPower.create(id, 1))
	hero.power_offer = [&"growth"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	var fire: Button = _button(screen, "LetFireGoButton")
	var leave: Button = _button(screen, "LeaveButton")
	fire.pressed.emit()
	leave.pressed.emit()
	assert_eq(fire.text, "Let Fire go (lv 1)")
	assert_eq(leave.text, "Sure? Growth is lost")
	fire.pressed.emit()
	assert_eq(_ids(), [&"fire", &"frost", &"stone"], "Fire was disarmed, so one press only arms it again")


func test_leave_it_behind_needs_a_second_press() -> void:
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	var leave: Button = _button(screen, "LeaveButton")
	leave.pressed.emit()
	assert_false(hero.power_offer.is_empty())
	leave.pressed.emit()
	await wait_process_frames(1)
	assert_true(hero.power_offer.is_empty())
	assert_true(hero.kept_powers.is_empty())
	assert_eq(_text(screen, "Subline"), "You left Fire behind.")


func test_a_maxed_power_can_only_be_left() -> void:
	hero.kept_powers.append(KeptPower.create(&"fire", 5))
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_null(_button(screen, "MergeButton"))
	assert_null(_button(screen, "KeepButton"))
	assert_not_null(_button(screen, "LeaveButton"))
	assert_eq(_text(screen, "Subline"), "Your Fire is at its highest level already.")


func test_no_offer_says_so() -> void:
	var screen: ChoiceScreen = await _open()
	assert_eq(_text(screen, "Headline"), "No power is waiting")
	assert_not_null(_button(screen, "ContinueButton"))


func test_slots_show_kept_powers_and_empty_slots() -> void:
	hero.kept_powers.append(KeptPower.create(&"stone", 4))
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	var slots: Node = screen.find_child("Slots", true, false)
	assert_eq(slots.get_child_count(), 3)
	assert_eq((slots.get_child(0).get_child(0) as Label).text, "Stone  lv 4\nBulwark")
	assert_eq((slots.get_child(1).get_child(0) as Label).text, "Empty slot")


# --- Give (M4) ------------------------------------------------------------------

func test_give_shows_villager_cards_with_previews() -> void:
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	_button(screen, "GiveButton").pressed.emit()
	await wait_process_frames(1)
	assert_eq(_text(screen, "Headline"), "Give Fire to a villager")
	var smith: Button = _button(screen, "SmithCard")
	assert_not_null(smith)
	for id: String in ["FarmerCard", "GuardCard", "HealerCard"]:
		assert_not_null(_button(screen, id), id)
	var novice: Label = smith.find_child("Novice", true, false) as Label
	assert_true(novice.text.begins_with("Novice: Sells a Fire infusion"), novice.text)
	assert_eq((smith.find_child("Master", true, false) as Label).text, "Master: ???", "Techniques stay hidden until the Codex")
	assert_null(smith.find_child("Start", true, false), "a level 1 gift starts at 0 TP")
	assert_false(screen.find_child("Slots", true, false).visible, "cards cover the slot row")
	assert_eq(screen.get_viewport().gui_get_focus_owner(), smith, "the first card has focus")


func test_giving_needs_a_second_press_and_is_forever() -> void:
	hero.power_offer = [&"growth"] as Array[StringName]
	watch_signals(EventBus)
	var screen: ChoiceScreen = await _open()
	_button(screen, "GiveButton").pressed.emit()
	await wait_process_frames(1)
	var farmer: Button = _button(screen, "FarmerCard")
	farmer.pressed.emit()
	assert_false(_village().find(&"farmer").has_power(), "the first press only arms the card")
	assert_eq(_text(screen, "Note"), "Press again to give Growth to Tilly the Farmer. It is theirs forever.")
	farmer.pressed.emit()
	await wait_process_frames(1)
	var state: VillagerState = _village().find(&"farmer")
	assert_eq(state.power_id, &"growth")
	assert_eq(state.training_points, 0)
	assert_true(hero.power_offer.is_empty())
	assert_true(hero.kept_powers.is_empty(), "a gift is not kept")
	assert_signal_emitted_with_parameters(EventBus, "power_given", [0, &"growth", _village().index_of(&"farmer")])
	assert_eq(_text(screen, "Subline"), "Tilly the Farmer now holds Growth.")
	assert_true(_text(screen, "Note").begins_with("\"Look, the seeds"), "the villager's line")
	assert_not_null(_button(screen, "ContinueButton"))


func test_a_villager_with_a_power_cannot_take_another() -> void:
	_village().find(&"smith").power_id = &"frost"
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	_button(screen, "GiveButton").pressed.emit()
	await wait_process_frames(1)
	var smith: Button = _button(screen, "SmithCard")
	assert_true(smith.disabled)
	assert_eq(screen.get_viewport().gui_get_focus_owner(), _button(screen, "FarmerCard"), "focus skips a villager who cannot take it")
	assert_eq((smith.find_child("Holds", true, false) as Label).text, "Holds Frost (Novice).")
	assert_false(screen.give(_village().index_of(&"smith")))
	assert_eq(_village().find(&"smith").power_id, &"frost")


func test_back_returns_to_the_offer() -> void:
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	_button(screen, "GiveButton").pressed.emit()
	await wait_process_frames(1)
	_button(screen, "BackButton").pressed.emit()
	await wait_process_frames(1)
	assert_eq(_text(screen, "Headline"), "A new power: Fire")
	assert_not_null(_button(screen, "KeepButton"))


func test_no_free_villager_hides_give() -> void:
	_fill_villagers()
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_null(_button(screen, "GiveButton"))
	assert_not_null(_button(screen, "KeepButton"))


func test_full_slots_give_a_kept_power_away_to_make_room() -> void:
	for id: StringName in [&"fire", &"frost", &"stone"]:
		hero.kept_powers.append(KeptPower.create(id, 3))
	hero.power_offer = [&"growth"] as Array[StringName]
	watch_signals(EventBus)
	var screen: ChoiceScreen = await _open()
	assert_null(_button(screen, "LetFrostGoButton"), "a free villager means no power is simply lost")
	_button(screen, "GiveKeptButton").pressed.emit()
	await wait_process_frames(1)
	assert_eq(_text(screen, "Headline"), "Give a kept power away")
	assert_eq(_text(screen, "Subline"), "Growth takes its slot at level 1.")
	_button(screen, "GiveFrostButton").pressed.emit()
	await wait_process_frames(1)
	assert_eq(_text(screen, "Headline"), "Give Frost to a villager")
	var guard: Button = _button(screen, "GuardCard")
	assert_eq((guard.find_child("Start", true, false) as Label).text, "Starts at 2 TP (Novice).", "level 3 carries 2 TP")
	guard.pressed.emit()
	guard.pressed.emit()
	await wait_process_frames(1)
	assert_eq(_village().find(&"guard").power_id, &"frost")
	assert_eq(_village().find(&"guard").training_points, 2)
	assert_eq(_ids(), [&"fire", &"growth", &"stone"], "Growth takes Frost's slot")
	assert_true(hero.power_offer.is_empty())
	assert_signal_emitted_with_parameters(EventBus, "power_kept", [0, &"growth"])
	assert_eq(_text(screen, "Subline"), "Maren the Guard now holds Frost. Growth takes its slot.")


func test_the_shrine_gives_a_kept_power_away_with_no_offer() -> void:
	hero.kept_powers.append(KeptPower.create(&"stone", 5))
	var screen: ChoiceScreen = await _open()
	assert_eq(_text(screen, "Headline"), "No power is waiting")
	_button(screen, "GiveStoneButton").pressed.emit()
	await wait_process_frames(1)
	var healer: Button = _button(screen, "HealerCard")
	assert_eq((healer.find_child("Start", true, false) as Label).text, "Starts at 4 TP (Adept).")
	healer.pressed.emit()
	healer.pressed.emit()
	await wait_process_frames(1)
	assert_eq(_village().find(&"healer").power_id, &"stone")
	assert_eq(_village().find(&"healer").training_points, 4)
	assert_true(hero.kept_powers.is_empty())
	assert_eq(_text(screen, "Subline"), "Osk the Healer now holds Stone.")


func test_continue_goes_back_to_the_village() -> void:
	assert_eq(ChoiceScreen.VILLAGE_SCENE, "res://scenes/village/village.tscn")


# --- Grow stronger (M4 PR 2) --------------------------------------------------------

func test_grow_stronger_spends_points_at_the_shrine_and_comes_back() -> void:
	hero.attribute_points = 2
	var screen: ChoiceScreen = await _open()
	var grow: Button = _button(screen, "GrowButton")
	assert_not_null(grow, "the Shrine offers growth with no offer waiting")
	grow.pressed.emit()
	await wait_process_frames(1)
	assert_not_null(screen.growth)
	assert_eq(screen.find_child("Headline", true, false).text, "Grow stronger")
	var might: Button = screen.growth.find_child("MightButton", true, false)
	assert_true(might.has_focus())
	might.pressed.emit()
	might.pressed.emit()
	assert_eq(hero.attribute(HeroState.MIGHT), 2)
	assert_eq(hero.attribute_points, 0)
	_button(screen, "BackButton").pressed.emit()
	await wait_process_frames(1)
	assert_null(screen.growth)
	assert_eq(screen.find_child("Headline", true, false).text, "No power is waiting")


func test_grow_stronger_is_there_while_deciding_and_after() -> void:
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_not_null(_button(screen, "GrowButton"), "level up before deciding")
	screen.keep()
	assert_not_null(_button(screen, "GrowButton"))
	_button(screen, "GrowButton").pressed.emit()
	_button(screen, "BackButton").pressed.emit()
	assert_eq(screen.find_child("Headline", true, false).text, "The Choice is made")
	assert_eq(screen.find_child("Subline", true, false).text, "Fire is kept in slot 1.")


# --- The forced first gift and the ceremony handoff (M4 PR 3) ------------------------

func test_the_first_power_must_go_to_the_farmer() -> void:
	GameState.profile.first_gift_done = false
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_eq(_text(screen, "Headline"), "Your first Spark: Fire")
	assert_eq(_text(screen, "Subline"), "The Elder: \"A Spark grows when it is shared. Give this one to Tilly the Farmer.\"")
	assert_null(_button(screen, "KeepButton"), "no keeping the first power")
	assert_null(_button(screen, "LeaveButton"), "no leaving it either")
	assert_not_null(_button(screen, "GrowButton"))
	assert_eq(_button(screen, "GiveButton").text, "Give to Tilly the Farmer")
	assert_false(screen.keep())
	screen.leave()
	assert_eq(hero.power_offer, [&"fire"] as Array[StringName], "keep and leave do nothing")
	_button(screen, "GiveButton").pressed.emit()
	await wait_process_frames(1)
	var smith: Button = _button(screen, "SmithCard")
	assert_true(smith.disabled, "only the Farmer can take the first gift")
	assert_eq((smith.find_child("Rule", true, false) as Label).text, "The Elder asks for someone else this time.")
	assert_eq(screen.get_viewport().gui_get_focus_owner(), _button(screen, "FarmerCard"))
	assert_false(screen.give(_village().index_of(&"smith")))
	var farmer: Button = _button(screen, "FarmerCard")
	farmer.pressed.emit()
	farmer.pressed.emit()
	await wait_process_frames(1)
	assert_eq(_village().find(&"farmer").power_id, &"fire")
	assert_true(GameState.profile.first_gift_done)
	assert_eq(screen.ceremony, {"villager_id": &"farmer", "power_id": &"fire", "first_gift": true})


func test_the_first_offer_still_lets_the_hero_pick_an_orb() -> void:
	GameState.profile.first_gift_done = false
	hero.power_offer = [&"fire", &"growth"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_eq(_text(screen, "Headline"), "2 Sparks broke free")
	_button(screen, "GrowthCard").pressed.emit()
	await wait_process_frames(1)
	assert_eq(_text(screen, "Headline"), "Your first Spark: Growth")


func test_later_choices_are_free_after_the_first_gift() -> void:
	GameState.profile.first_gift_done = false
	GiftSystem.give(_village(), _village().index_of(&"farmer"), &"growth")
	hero.power_offer = [&"fire"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_eq(_text(screen, "Headline"), "A new power: Fire", "the Farmer is taken, so nothing is forced")
	assert_not_null(_button(screen, "KeepButton"))


func test_a_gift_sets_up_the_ceremony() -> void:
	hero.power_offer = [&"stone"] as Array[StringName]
	var screen: ChoiceScreen = await _open()
	assert_true(screen.ceremony.is_empty())
	screen.start_give(&"stone", false)
	assert_true(screen.give(_village().index_of(&"guard")))
	assert_eq(screen.ceremony, {"villager_id": &"guard", "power_id": &"stone", "first_gift": false})
