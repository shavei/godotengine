extends Node
## Owns the current profile (heroes keyed by player_id, and the shared village) and the
## run in progress. Loads and saves both through SaveManager.
## Rule: never store per-player data directly on this node; key it by player_id.

const LOCAL_PLAYER_ID: int = 0
## Renown arrives in M5. Until then the village counts as Renown 2, so the four
## prototype villagers (Smith, Farmer, Guard and the Healer) all live there.
const RENOWN_LEVEL_UNTIL_M5: int = 2

## The save slot in use. One slot until a slot picker exists.
var slot: int = 0
## Long-term progress. Replaced by the slot's save at boot (load_profile()).
var profile: ProfileState = ProfileState.new()
## The run in progress, or null in the village and menus. Shared by the whole party;
## per-hero data inside it is keyed by player_id.
var run: RunState = null


func new_profile() -> void:
	profile = ProfileState.new()
	profile.hero(LOCAL_PLAYER_ID)
	admit_villagers()


## Moves in the villagers whose Renown level is reached (a fresh village, or an old save
## from before a villager existed).
func admit_villagers() -> void:
	var roster: Array[VillagerData] = []
	for item: Resource in ContentDB.get_all(&"villagers"):
		if item is VillagerData:
			roster.append(item)
	profile.village.admit(roster, RENOWN_LEVEL_UNTIL_M5)


func has_profile() -> bool:
	return not profile.heroes.is_empty()


## Loads the slot's profile, or starts a fresh one if there is no save.
func load_profile() -> void:
	var data: Dictionary = SaveManager.load_data(slot)
	if data.is_empty():
		new_profile()
	else:
		profile = ProfileState.from_dict(data)
		profile.hero(LOCAL_PLAYER_ID)
		admit_villagers()


func save_profile() -> Error:
	return SaveManager.save_data(slot, profile.to_dict())


## The hero's long-term progress (level, attributes, bank).
func hero_state(player_id: int) -> HeroState:
	return profile.hero(player_id)


# --- Run in progress ---------------------------------------------------------

func has_saved_run() -> bool:
	return SaveManager.has_run(slot)


## Writes the run in progress so it can be continued after quitting or a crash.
func save_run() -> Error:
	if run == null:
		return ERR_DOES_NOT_EXIST
	return SaveManager.save_run(slot, run.to_dict())


## Loads the saved run into `run`. Returns false (and deletes the file) if it no longer
## fits the game's content, so a broken save never blocks the title.
func load_saved_run() -> bool:
	var data: Dictionary = SaveManager.load_run(slot)
	var region: RegionData = ContentDB.get_item(&"regions", StringName(str(data.get("region", "")))) as RegionData
	var loaded: RunState = RunState.from_dict(data, region) if not data.is_empty() else null
	if loaded == null:
		SaveManager.delete_run(slot)
		return false
	run = loaded
	return true


## The run is over: forget it and its save.
func end_run() -> void:
	run = null
	SaveManager.delete_run(slot)
