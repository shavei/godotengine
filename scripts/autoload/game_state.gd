extends Node
## Owns the current profile (heroes keyed by player_id, and the shared village) and the
## run in progress. Loads and saves both through SaveManager.
## Rule: never store per-player data directly on this node; key it by player_id.

const LOCAL_PLAYER_ID: int = 0

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


## Moves in the villagers whose Renown level is reached (a fresh village, an old save
## from before a villager existed, or a new Renown level). `renown_level` overrides the
## village's own level (tests). Returns the new arrivals.
func admit_villagers(renown_level: int = -1) -> Array[VillagerState]:
	var level: int = renown_level if renown_level > 0 else RenownSystem.level(profile.village, balance())
	return profile.village.admit(roster(), level)


## Every villager in the game's content.
func roster() -> Array[VillagerData]:
	var result: Array[VillagerData] = []
	for item: Resource in ContentDB.get_all(&"villagers"):
		if item is VillagerData:
			result.append(item)
	return result


## The game's balance numbers (defaults if the file is missing).
func balance() -> BalanceData:
	var data: BalanceData = ContentDB.get_item(&"balance", &"default") as BalanceData
	return data if data != null else BalanceData.new()


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
		# Saves from before Renown take their level as already seen.
		if profile.village.renown_seen < 0:
			profile.village.renown_seen = RenownSystem.level(profile.village, balance())


func save_profile() -> Error:
	return SaveManager.save_data(slot, profile.to_dict())


## The hero's long-term progress (level, attributes, bank).
func hero_state(player_id: int) -> HeroState:
	return profile.hero(player_id)


## What the village does for this hero's runs (docs/ARCHITECTURE.md Section 5).
func services(player_id: int) -> ModifierStack:
	var combos: Array[ComboData] = []
	for item: Resource in ContentDB.get_all(&"combos"):
		if item is ComboData:
			combos.append(item)
	return ModifierStack.collect(hero_state(player_id), profile.village, balance(), roster(), combos)


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
