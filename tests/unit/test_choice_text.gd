extends GutTest
## ChoiceText: the plain words of the Choice screen.

var balance: BalanceData = BalanceData.new()


func test_the_timeline_counts_runs_to_adept_and_master() -> void:
	var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(&"farmer", &"growth")) as ComboData
	var steps: PackedStringArray = ChoiceText.timeline(combo, 0, balance)
	assert_eq(steps.size(), 3)
	assert_true(steps[0].begins_with("Now: "), steps[0])
	assert_true(steps[1].begins_with("In 3 runs, Adept: "), steps[1])
	assert_true(steps[2].begins_with("In 7 runs, Master: teaches you %s." % combo.technique.display_name), steps[2])


func test_a_gift_that_starts_ahead_counts_fewer_runs() -> void:
	var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(&"smith", &"fire")) as ComboData
	var steps: PackedStringArray = ChoiceText.timeline(combo, 4, balance)
	assert_true(steps[1].begins_with("Adept now: "), steps[1])
	assert_true(steps[2].begins_with("In 3 runs, Master: "), steps[2])
	assert_true(ChoiceText.timeline(combo, 6, balance)[2].begins_with("In 1 run, Master: "))


func test_every_line_is_plain_and_has_no_em_dash() -> void:
	var texts: PackedStringArray = []
	texts.append_array(ChoiceText.keep_lines(2, "E", 6.0))
	texts.append_array(ChoiceText.merge_lines("Fire", 3, "Level 3: explodes."))
	texts.append_array(ChoiceText.give_lines(balance))
	texts.append_array(ChoiceText.how_lines(balance))
	texts.append(ChoiceText.PICK_HINT)
	texts.append(ChoiceText.keep_hint("Fire", 1, "Q"))
	texts.append(ChoiceText.leave_hint("Fire"))
	texts.append(ChoiceText.let_go_hint("Fire", "Frost"))
	for text: String in texts:
		assert_false(text.contains("—"), text)
	assert_eq(ChoiceText.keep_lines(2, "E", 6.0)[0], "Yours in every run, on Power button 2 (E).")
	assert_eq(ChoiceText.merge_lines("Fire", 3, "")[0], "Your Fire goes from level 2 to 3.")


func test_the_help_card_reads_its_numbers_from_the_balance() -> void:
	var tuned: BalanceData = BalanceData.new()
	tuned.adept_tp = 4
	tuned.master_tp = 9
	var lines: PackedStringArray = ChoiceText.how_lines(tuned)
	assert_true(lines[0].ends_with("You have %d slots." % GiftSystem.slot_count(tuned)), lines[0])
	assert_true(lines[2].contains("In 4 runs they are Adept, in 9 a Master"), lines[2])
