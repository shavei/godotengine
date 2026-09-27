class_name RunState
extends RefCounted
## The current run only (docs/ARCHITECTURE.md Section 4.2): region, seed, the floor map,
## where the party is, and what each hero carries between rooms (HP, flasks and the
## run's loot Wallet). Hero entries are keyed by player_id so co-op can add heroes later.
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
## player_id -> { "hp": int, "max_hp": int, "flasks": int }
var heroes: Dictionary = {}
## player_id -> Wallet: what each hero picked up this run.
var wallets: Dictionary[int, Wallet] = {}
var rooms_cleared: int = 0


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


func save_hero(player_id: int, hp: int, max_hp: int, flasks: int) -> void:
	heroes[player_id] = {"hp": hp, "max_hp": max_hp, "flasks": flasks}


## What the hero carried out of the last room, or an empty Dictionary at the start.
func hero_snapshot(player_id: int) -> Dictionary:
	return heroes.get(player_id, {})


## The hero's loot for this run. Made empty the first time it is asked for.
func wallet(player_id: int) -> Wallet:
	if not wallets.has(player_id):
		wallets[player_id] = Wallet.new()
	return wallets[player_id]


func _build_floor(index: int) -> void:
	floor_index = index
	map = RunGenerator.generate_floor(region, index, run_seed)
	current_room_id = -1
	room_cleared = true
	path.clear()
