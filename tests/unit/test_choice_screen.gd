extends GutTest
## The Choice screen (keep screen in M3): take one orb, then keep, merge, let a kept
## power go, or leave the new power behind.

const CHOICE_SCENE: PackedScene = preload("res://scenes/ui/choice_screen.tscn")

var _original_profile: ProfileState
var _original_context: Dictionary
var hero: HeroState


func before_each() -> void:
	_original_profile = GameState.profile
	_original_context = SceneRouter.context
	GameState.new_profile()
	hero = GameState.hero_state(GameState.LOCAL_PLAYER_ID)


func after_each() -> void:
	GameState.profile = _original_profile
	SceneRouter.context = _original_context


func _open() -> ChoiceScreen:
	SceneRouter.context = {"player_id": GameState.LOCAL_PLAYER_ID}
	var screen: ChoiceScreen = CHOICE_SCENE.instantiate()
	screen.save_on_change = false
	add_child_autofree(screen)
	await wait_process_frames(1)
	return screen


func _button(screen: ChoiceScreen, node_name: String) -> Button:
	var node: Node = screen.find_child(node_name, true, false)
	return node as Button if node != null and not node.is_queued_for_deletion() else null


func _text(screen: ChoiceScreen, node_name: String) -> String:
	return (screen.find_child(node_name, true, false) as Label).text


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
