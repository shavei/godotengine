class_name ChoiceText
extends RefCounted
## Plain words for the Choice screen (docs/GDD.md Section 3.1): what keeping a power
## gives, what giving it does, when a gift pays back, and what each button does.
## The owner's playtest (2026-09-29) found the Choice confusing on every count, so each
## option now says in one line what you gain and what you lose (pillar 1).


## "If you keep it": where the power goes and how it grows.
static func keep_lines(slot: int, button: String, cooldown: float) -> PackedStringArray:
	return [
		"Yours in every run, on Power button %d (%s)." % [slot, button],
		"Ready again %d s after you use it." % roundi(cooldown),
		"Level it up with Power Shards here.",
	]


## "If you merge it": the level it reaches and what that level adds.
static func merge_lines(power_name: String, level: int, level_note: String) -> PackedStringArray:
	var lines: PackedStringArray = ["Your %s goes from level %d to %d." % [power_name, level - 1, level]]
	if not level_note.is_empty():
		lines.append(level_note)
	lines.append("It stays in its slot; no new slot is used.")
	return lines


## "If you give it": what every gift does, and when it comes back.
static func give_lines(balance: BalanceData) -> PackedStringArray:
	return [
		"A villager holds it forever. Their service helps every run from now on.",
		"In %d runs they are Adept (a better service)." % balance.adept_tp,
		"In %d runs they are a Master and teach you a Technique: yours for good, no slot needed." % balance.master_tp,
	]


## A villager card's timeline for one gift: now, Adept, Master (with the Technique).
## `start_tp` is where the gift starts (a kept power given away starts ahead).
static func timeline(combo: ComboData, start_tp: int, balance: BalanceData) -> PackedStringArray:
	var lines: PackedStringArray = ["Now: %s" % combo.novice.description]
	lines.append("%s: %s" % [_when("Adept", balance.adept_tp - start_tp), combo.adept.description])
	if combo.technique != null:
		lines.append("%s: teaches you %s. %s" % [_when("Master", balance.master_tp - start_tp),
				combo.technique.display_name, combo.technique.description])
	return lines


## One line under the buttons for the button that has focus: what pressing it does.
static func keep_hint(power_name: String, slot: int, button: String) -> String:
	return "Keep: %s goes on Power button %d (%s) for your next run. No villager gets it." % [power_name, slot, button]


static func merge_hint(power_name: String, level: int) -> String:
	return "Merge: %s goes from level %d to %d. It stays in its slot." % [power_name, level - 1, level]


static func give_hint(power_name: String) -> String:
	return "Give: pick a villager next. %s is theirs forever, and at Master they teach you a Technique." % power_name


static func give_kept_hint(new_name: String) -> String:
	return "Give a kept power away to make room. It keeps its level, so the villager starts ahead. %s takes the free slot." % new_name


static func let_go_hint(old_name: String, new_name: String) -> String:
	return "Let %s go: it is gone for good, with the shards spent on it. %s takes its slot." % [old_name, new_name]


static func leave_hint(power_name: String) -> String:
	return "Leave %s behind: it is gone. Nothing else changes." % power_name


const GROW_HINT: String = "Grow stronger: spend attribute points and Power Shards."
const CONTINUE_HINT: String = "Back to the village. A power you have not settled waits here."
const DONE_HINT: String = "Back to the village."
const BACK_HINT: String = "Back to the power."
const HOW_HINT: String = "How the Choice works, in four lines."

## The one-time card that explains the Choice (and the "How it works" button).
const HOW_TITLE: String = "How the Choice works"
const HOW_LINES: PackedStringArray = [
	"Keep it: you are stronger in your next run. You have 3 slots.",
	"Give it: a villager holds it forever, and their service helps every run.",
	"Every run they train it. In 3 runs they are Adept, in 7 a Master who teaches you a Technique: yours for good, no slot needed.",
	"Merge: a power you keep already gains a level. Leave it: it is gone.",
]


## "In 3 runs, Adept" or "Adept now" (a kept power given away can start there).
static func _when(rank: String, runs: int) -> String:
	return "%s now" % rank if runs <= 0 else "In %d %s, %s" % [runs, "run" if runs == 1 else "runs", rank]
