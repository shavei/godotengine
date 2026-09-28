class_name ProfileState
extends RefCounted
## Everything a save slot keeps between runs (docs/ARCHITECTURE.md Section 4.2).
## Heroes are keyed by player_id; player 0 is the local owner. The village joins in M4.

var run_count: int = 0
var runs_won: int = 0
var heroes: Dictionary[int, HeroState] = {}


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
	}


static func from_dict(data: Dictionary) -> ProfileState:
	var profile: ProfileState = ProfileState.new()
	profile.run_count = int(data.get("run_count", 0))
	profile.runs_won = int(data.get("runs_won", 0))
	var hero_data: Dictionary = data.get("heroes", {})
	for key: Variant in hero_data:
		if hero_data[key] is Dictionary:
			profile.heroes[int(str(key))] = HeroState.from_dict(hero_data[key])
	return profile
