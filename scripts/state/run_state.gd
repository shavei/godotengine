class_name RunState
extends RefCounted
## The current run only (docs/ARCHITECTURE.md Section 4.2): region, seed, the floor map,
## where the party is, and what each hero carries between rooms (HP, flasks and the
## run's loot Wallet), plus the XP and weapon damage each hero earns. Hero entries are
## keyed by player_id so co-op can add heroes later. to_dict() / from_dict() are the
## mid-run save (docs/ARCHITECTURE.md Section 10).
##
## Before the first room of a floor the party is in the floor's safe corridor
## (current_room_id == -1).

var region: RegionData
var run_seed: int = 0
var floor_index: int = 0
var map: FloorMap
var current_room_id: int = -1
## True once the current room is done (always true in the corridor).
var room_cleared: bool = true
## Room ids visited on the current floor, in order.
var path: Array[int] = []
## player_id -> { "hp": int, "max_hp": int, "flasks": int, "revives": int, "clean_rooms": int }
## (revive tokens left; fight rooms cleared in a row without being hit).
var heroes: Dictionary = {}
## player_id -> Wallet: what each hero picked up this run.
var wallets: Dictionary[int, Wallet] = {}
## player_id -> XP earned this run (banked into the hero's level at the run's end).
var xp: Dictionary[int, int] = {}
## player_id -> { weapon_id -> damage dealt this run } (becomes weapon mastery).
var weapon_damage: Dictionary[int, Dictionary] = {}
var rooms_cleared: int = 0
## Seconds played this run (paused time does not count).
var elapsed: float = 0.0


static func start(run_region: RegionData, seed_value: int) -> RunState:
	var run: RunState = RunState.new()
	run.region = run_region
	run.run_seed = seed_value
	run._build_floor(0)
	return run


func current_room() -> MapRoom:
	return map.get_room(current_room_id)


func is_in_corridor() -> bool:
	return current_room_id < 0


func is_last_floor() -> bool:
	return floor_index >= region.floor_count - 1


## The exit room is cleared: the floor is done.
func is_floor_done() -> bool:
	var room: MapRoom = current_room()
	return room != null and room == map.exit_room() and room_cleared


func is_run_won() -> bool:
	return is_floor_done() and is_last_floor()


## Rooms the party may go to now (empty until the current room is cleared).
func next_choices() -> Array[int]:
	if not room_cleared:
		return []
	return map.next_ids(current_room_id)


## Moves into `room_id` if it is one of the current choices.
func enter(room_id: int) -> bool:
	if not next_choices().has(room_id):
		return false
	current_room_id = room_id
	path.append(room_id)
	room_cleared = false
	return true


func mark_cleared() -> void:
	if not room_cleared:
		room_cleared = true
		rooms_cleared += 1


## After a floor's exit is cleared, goes to the next floor's corridor.
func advance_floor() -> bool:
	if not is_floor_done() or is_last_floor():
		return false
	_build_floor(floor_index + 1)
	return true


func save_hero(player_id: int, hp: int, max_hp: int, flasks: int, revives: int = 0, clean_rooms: int = 0) -> void:
	heroes[player_id] = {"hp": hp, "max_hp": max_hp, "flasks": flasks, "revives": revives, "clean_rooms": clean_rooms}


## What the hero carried out of the last room, or an empty Dictionary at the start.
func hero_snapshot(player_id: int) -> Dictionary:
	return heroes.get(player_id, {})


## The hero's loot for this run. Made empty the first time it is asked for.
func wallet(player_id: int) -> Wallet:
	if not wallets.has(player_id):
		wallets[player_id] = Wallet.new()
	return wallets[player_id]


func add_xp(player_id: int, amount: int) -> void:
	if amount > 0:
		xp[player_id] = xp.get(player_id, 0) + amount


func xp_earned(player_id: int) -> int:
	return xp.get(player_id, 0)


func add_weapon_damage(player_id: int, weapon_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	if not weapon_damage.has(player_id):
		weapon_damage[player_id] = {}
	var dealt: Dictionary = weapon_damage[player_id]
	dealt[weapon_id] = int(dealt.get(weapon_id, 0)) + amount


## weapon_id -> damage the hero dealt with it this run.
func damage_by_weapon(player_id: int) -> Dictionary:
	return weapon_damage.get(player_id, {})


## Every player_id that has anything in this run (HP, loot or XP).
func player_ids() -> Array[int]:
	var ids: Array[int] = []
	for source: Dictionary in [heroes, wallets, xp, weapon_damage]:
		for player_id: int in source:
			if not ids.has(player_id):
				ids.append(player_id)
	ids.sort()
	return ids


## A JSON-safe copy for the mid-run save. The floor map is rebuilt from the seed on load.
func to_dict() -> Dictionary:
	var hero_data: Dictionary = {}
	for player_id: int in player_ids():
		var damage: Dictionary = {}
		var dealt: Dictionary = damage_by_weapon(player_id)
		for weapon_id: Variant in dealt:
			damage[str(weapon_id)] = dealt[weapon_id]
		hero_data[str(player_id)] = {
			"carry": hero_snapshot(player_id).duplicate(),
			"wallet": wallet(player_id).to_dict(),
			"xp": xp_earned(player_id),
			"weapon_damage": damage,
		}
	return {
		"region": String(region.id),
		"seed": run_seed,
		"floor": floor_index,
		"room": current_room_id,
		"room_cleared": room_cleared,
		"path": path.duplicate(),
		"rooms_cleared": rooms_cleared,
		"elapsed": elapsed,
		"heroes": hero_data,
	}


## Rebuilds a run saved by to_dict(). `run_region` must be the region named in the data.
## Returns null if the data does not fit the region (a changed map, a missing room).
static func from_dict(data: Dictionary, run_region: RegionData) -> RunState:
	if run_region == null or str(data.get("region", "")) != String(run_region.id):
		return null
	var floor_number: int = int(data.get("floor", 0))
	if floor_number < 0 or floor_number >= run_region.floor_count:
		return null
	var run: RunState = RunState.new()
	run.region = run_region
	run.run_seed = int(data.get("seed", 0))
	run._build_floor(floor_number)
	for room_id: Variant in data.get("path", []):
		run.path.append(int(room_id))
	run.current_room_id = int(data.get("room", -1))
	if run.current_room_id >= 0 and run.current_room() == null:
		return null
	run.room_cleared = bool(data.get("room_cleared", run.current_room_id < 0))
	run.rooms_cleared = int(data.get("rooms_cleared", 0))
	run.elapsed = float(data.get("elapsed", 0.0))
	var hero_data: Dictionary = data.get("heroes", {})
	for key: Variant in hero_data:
		var player_id: int = int(str(key))
		var entry: Dictionary = hero_data[key]
		var carry: Dictionary = entry.get("carry", {})
		if not carry.is_empty():
			run.save_hero(player_id, int(carry.get("hp", 1)), int(carry.get("max_hp", 1)), int(carry.get("flasks", 0)),
					int(carry.get("revives", 0)), int(carry.get("clean_rooms", 0)))
		run.wallets[player_id] = Wallet.from_dict(entry.get("wallet", {}))
		run.add_xp(player_id, int(entry.get("xp", 0)))
		var damage: Dictionary = entry.get("weapon_damage", {})
		for weapon_id: Variant in damage:
			run.add_weapon_damage(player_id, StringName(str(weapon_id)), int(damage[weapon_id]))
	return run


func _build_floor(index: int) -> void:
	floor_index = index
	map = RunGenerator.generate_floor(region, index, run_seed)
	current_room_id = -1
	room_cleared = true
	path.clear()
