class_name ConsoleCommands
extends RefCounted
## The debug console's profile commands (docs/ARCHITECTURE.md Section 11), for testing
## the village loop without playing every run. The DebugConsole autoload handles the
## commands that need the scene (skip_room, god_mode) and hands the rest to run().
## Each command returns {"ok": bool, "text": String, "changed": bool}; "changed" means the
## profile changed and should be saved (and the village shown again).

## [usage, what it does], in help order.
const COMMANDS: Array[Array] = [
	["give_power <power>", "A power waits at the Shrine (fire, frost, growth, stone)."],
	["set_tp <villager> <points>", "Sets a villager's Training Points (Adept at 3, Master at 7)."],
	["add_renown <points>", "Adds Renown points to the village."],
	["skip_room", "Clears the room you are in (in a run)."],
	["god_mode", "You take no damage (on or off)."],
	["help", "Lists the commands."],
]


## The line's words, lower case, without extra spaces.
static func words(line: String) -> PackedStringArray:
	return line.strip_edges().to_lower().split(" ", false)


static func help_text() -> String:
	var lines: PackedStringArray = []
	for command: Array in COMMANDS:
		lines.append("%s: %s" % [command[0], command[1]])
	return "\n".join(lines)


## Runs a profile command. Unknown commands and wrong arguments return ok = false.
static func run(args: PackedStringArray, profile: ProfileState, player_id: int, balance: BalanceData,
		powers: Array[PowerData]) -> Dictionary:
	if args.is_empty():
		return _result(false, "")
	match args[0]:
		"help":
			return _result(true, help_text())
		"give_power":
			if args.size() != 2:
				return _result(false, "Usage: give_power <power>")
			return give_power(profile.hero(player_id), StringName(args[1]), powers)
		"set_tp":
			if args.size() != 3 or not args[2].is_valid_int():
				return _result(false, "Usage: set_tp <villager> <points>")
			return set_tp(profile.village, StringName(args[1]), args[2].to_int(), balance)
		"add_renown":
			if args.size() != 2 or not args[1].is_valid_int():
				return _result(false, "Usage: add_renown <points>")
			return add_renown(profile.village, args[1].to_int(), balance)
	return _result(false, "Unknown command: %s. Type help." % args[0])


## Puts `power_id` at the Shrine as the waiting power (replacing any offer).
static func give_power(hero: HeroState, power_id: StringName, powers: Array[PowerData]) -> Dictionary:
	var names: PackedStringArray = []
	for power: PowerData in powers:
		if power.id == power_id:
			hero.power_offer = [power_id] as Array[StringName]
			return _result(true, "%s waits at the Shrine." % power.display_name, true)
		names.append(String(power.id))
	names.sort()
	return _result(false, "No power called %s. Try: %s" % [power_id, ", ".join(names)])


## Sets the Training Points of the villager with this job (they must hold a power).
static func set_tp(village: VillageState, villager_id: StringName, points: int, balance: BalanceData) -> Dictionary:
	var villager: VillagerState = village.find(villager_id)
	if villager == null:
		var ids: PackedStringArray = []
		for other: VillagerState in village.villagers:
			ids.append(String(other.villager_id))
		return _result(false, "No %s lives here. Villagers: %s" % [villager_id, ", ".join(ids)])
	if not villager.has_power():
		return _result(false, "The %s holds no power yet. Give one first." % villager_id)
	villager.training_points = maxi(points, 0)
	return _result(true, "The %s has %d TP (%s)." % [villager_id, villager.training_points,
			TrainingSystem.rank_name(TrainingSystem.rank(villager, balance))], true)


## Adds Renown points (a negative amount takes back points added this way).
static func add_renown(village: VillageState, amount: int, balance: BalanceData) -> Dictionary:
	village.bonus_renown = maxi(village.bonus_renown + amount, 0)
	return _result(true, "%s." % RenownSystem.text(village, balance), true)


static func _result(ok: bool, text: String, changed: bool = false) -> Dictionary:
	return {"ok": ok, "text": text, "changed": changed}
