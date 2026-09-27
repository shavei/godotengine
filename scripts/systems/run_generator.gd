class_name RunGenerator
extends RefCounted
## Builds seeded floor maps (docs/GDD.md Section 6.1). The same region, floor and run
## seed always give the same map, so co-op peers and daily runs can agree on it.
##
## Rules:
## - Every row has min_row_width to max_row_width rooms; the exit row has one room.
## - Every room leads to at least one room in the next row and every room has a way
##   in, so the whole floor is reachable. Paths never cross on the map.
## - The first row is always a fight. Elites wait until `elite_min_row`.
## - A row never offers the same non-fight room twice, so doors differ.
## - Floors end in a mini-boss, the last floor in the region boss.

const REROLLS: int = 12


static func generate_floor(region: RegionData, floor_index: int, run_seed: int) -> FloorMap:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = floor_seed(run_seed, floor_index)
	var map: FloorMap = FloorMap.new()
	map.floor_index = floor_index
	var depth: int = rng.randi_range(region.min_depth, maxi(region.min_depth, region.max_depth))
	for row: int in depth:
		var width: int = rng.randi_range(region.min_row_width, maxi(region.min_row_width, region.max_row_width))
		var rooms: Array[MapRoom] = map.add_row(width)
		_assign_types(rooms, row, region, rng)
	var exit: MapRoom = map.add_row(1)[0]
	exit.type = MapRoom.BOSS if floor_index >= region.floor_count - 1 else MapRoom.MINI_BOSS
	for row: int in map.row_count() - 1:
		_connect_rows(map.get_row(row), map.get_row(row + 1), region.branch_chance, rng)
	return map


static func floor_seed(run_seed: int, floor_index: int) -> int:
	return hash([run_seed, floor_index])


## The encounter a fight room uses, or null for rooms without a fight.
static func pick_encounter(region: RegionData, map: FloorMap, room: MapRoom, run_seed: int) -> EncounterData:
	var pool: Array[EncounterData] = []
	match room.type:
		MapRoom.COMBAT:
			pool = region.combat_encounters
		MapRoom.ELITE:
			pool = region.elite_encounters
		MapRoom.MINI_BOSS:
			return region.mini_boss_encounter
		MapRoom.BOSS:
			return region.boss_encounter
	if pool.is_empty():
		return null
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, map.floor_index, room.id, &"encounter"])
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _assign_types(rooms: Array[MapRoom], row: int, region: RegionData, rng: RandomNumberGenerator) -> void:
	var used: Array[StringName] = []
	for room: MapRoom in rooms:
		room.type = MapRoom.COMBAT
		if row == 0:
			continue
		for attempt: int in REROLLS:
			var type: StringName = _roll_type(region.room_weights, rng)
			if type == MapRoom.ELITE and row < region.elite_min_row:
				continue
			if type != MapRoom.COMBAT and used.has(type):
				continue
			room.type = type
			break
		used.append(room.type)


static func _roll_type(weights: Dictionary[StringName, float], rng: RandomNumberGenerator) -> StringName:
	var total: float = 0.0
	for weight: float in weights.values():
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return MapRoom.COMBAT
	var roll: float = rng.randf() * total
	for type: StringName in weights:
		roll -= maxf(weights[type], 0.0)
		if roll < 0.0:
			return type
	return MapRoom.COMBAT


## Links two rows without crossing paths: each room first goes to the room nearest
## its own place in the row, rooms left without a way in are linked from the left,
## then extra doors are added where they cross nothing.
static func _connect_rows(from: Array[MapRoom], to: Array[MapRoom], branch_chance: float, rng: RandomNumberGenerator) -> void:
	var links: Array[Vector2i] = []
	var reached: Dictionary = {}
	for room: MapRoom in from:
		var place: float = (room.lane + 0.5) / from.size()
		var lane: int = clampi(floori(place * to.size()), 0, to.size() - 1)
		links.append(Vector2i(room.lane, lane))
		reached[lane] = true
	for lane: int in to.size():
		if reached.has(lane):
			continue
		# The rightmost room whose nearest link is left of this lane, else the first room.
		var source: int = 0
		for link: Vector2i in links:
			if link.y < lane:
				source = maxi(source, link.x)
		links.append(Vector2i(source, lane))
	for room: MapRoom in from:
		for step: int in [-1, 1]:
			var own: Array[int] = []
			for link: Vector2i in links:
				if link.x == room.lane:
					own.append(link.y)
			var target: int = (own.max() + 1) if step > 0 else (own.min() - 1)
			if target < 0 or target >= to.size() or rng.randf() >= branch_chance:
				continue
			var candidate: Vector2i = Vector2i(room.lane, target)
			if not _crosses(candidate, links):
				links.append(candidate)
	links.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y)
	for link: Vector2i in links:
		from[link.x].next.append(to[link.y].id)


static func _crosses(link: Vector2i, links: Array[Vector2i]) -> bool:
	for other: Vector2i in links:
		if (link.x < other.x and link.y > other.y) or (link.x > other.x and link.y < other.y):
			return true
	return false
