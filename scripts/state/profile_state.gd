class_name ProfileState
extends RefCounted
## Everything a save slot keeps between runs (docs/ARCHITECTURE.md Section 4.2).
## Heroes are keyed by player_id; player 0 is the local owner. The village is shared.

var run_count: int = 0
var runs_won: int = 0
var heroes: Dictionary[int, HeroState] = {}
var village: VillageState = VillageState.new()
## True once the first power has been given (the forced first gift, FirstGift).
var first_gift_done: bool = false
## Gift ceremonies watched to the end or skipped; the first one cannot be skipped.
var ceremonies_seen: int = 0
## True once the Choice screen's "How the Choice works" card was shown (it opens by
## itself only the first time).
var choice_help_seen: bool = false
## Training ticks the runs left waiting (TrainingSystem.train_due): one per run, applied
## in the village once nothing waits at the Shrine.
var training_due: int = 0


## The hero's progress. Made fresh (level 1) the first time it is asked for.
func hero(player_id: int) -> HeroState:
	if not heroes.has(player_id):
		heroes[player_id] = HeroState.new()
	return heroes[player_id]


func to_dict() -> Dictionary:
	var hero_data: Dictionary = {}
	for player_id: int in heroes:
		hero_data[str(player_id)] = heroes[player_id].to_dict()
	return {
		"run_count": run_count,
		"runs_won": runs_won,
		"heroes": hero_data,
		"village": village.to_dict(),
		"first_gift_done": first_gift_done,
		"ceremonies_seen": ceremonies_seen,
		"choice_help_seen": choice_help_seen,
		"training_due": training_due,
	}


static func from_dict(data: Dictionary) -> ProfileState:
	var profile: ProfileState = ProfileState.new()
	profile.run_count = int(data.get("run_count", 0))
	profile.runs_won = int(data.get("runs_won", 0))
	var hero_data: Dictionary = data.get("heroes", {})
	for key: Variant in hero_data:
		if hero_data[key] is Dictionary:
			profile.heroes[int(str(key))] = HeroState.from_dict(hero_data[key])
	var village_data: Variant = data.get("village", {})
	profile.village = VillageState.from_dict(village_data if village_data is Dictionary else {})
	# Saves from before the tutorial: anyone who gave or kept a power is past it.
	profile.first_gift_done = bool(data.get("first_gift_done", FirstGift.settled_before(profile)))
	profile.ceremonies_seen = maxi(0, int(data.get("ceremonies_seen", 0)))
	profile.choice_help_seen = bool(data.get("choice_help_seen", false))
	profile.training_due = maxi(0, int(data.get("training_due", 0)))
	return profile
