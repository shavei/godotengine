extends GutTest
## Floor map rules (RunGenerator, docs/GDD.md Section 6.1).

const REGION_PATH: String = "res://data/regions/region_mossy_hollow.tres"
const SEEDS: int = 200

var region: RegionData


func before_all() -> void:
	region = load(REGION_PATH)


func test_same_seed_gives_same_map() -> void:
	var a: FloorMap = RunGenerator.generate_floor(region, 1, 12345)
	var b: FloorMap = RunGenerator.generate_floor(region, 1, 12345)
	assert_eq(_describe(a), _describe(b))


func test_different_seeds_and_floors_give_different_maps() -> void:
	var base: String = _describe(RunGenerator.generate_floor(region, 0, 1))
	var other_seed_differs: bool = false
	var other_floor_differs: bool = false
	for i: int in range(2, 12):
		other_seed_differs = other_seed_differs or _describe(RunGenerator.generate_floor(region, 0, i)) != base
	other_floor_differs = _describe(RunGenerator.generate_floor(region, 1, 1)) != base
	assert_true(other_seed_differs)
	assert_true(other_floor_differs)


func test_shape_depth_and_row_width() -> void:
	for s: int in SEEDS:
		var map: FloorMap = RunGenerator.generate_floor(region, s % 3, s)
		assert_between(map.depth(), region.min_depth, region.max_depth)
		for row: int in map.depth():
			assert_between(map.get_row(row).size(), region.min_row_width, region.max_row_width)
		assert_eq(map.get_row(map.depth()).size(), 1, "one exit room")
		assert_eq(map.exit_room(), map.get_row(map.depth())[0])


func test_links_only_go_to_the_next_row() -> void:
	for s: int in SEEDS:
		var map: FloorMap = RunGenerator.generate_floor(region, 0, s)
		for room: MapRoom in map.rooms:
			for next_id: int in room.next:
				assert_eq(map.get_room(next_id).row, room.row + 1)


func test_every_room_has_a_way_in_and_out() -> void:
	for s: int in SEEDS:
		var map: FloorMap = RunGenerator.generate_floor(region, 0, s)
		var incoming: Dictionary = {}
		for room: MapRoom in map.rooms:
			for next_id: int in room.next:
				incoming[next_id] = true
		for room: MapRoom in map.rooms:
			if room != map.exit_room():
				assert_gt(room.next.size(), 0, "room %d leads nowhere (seed %d)" % [room.id, s])
			else:
				assert_eq(room.next.size(), 0)
			if room.row > 0:
				assert_true(incoming.has(room.id), "room %d cannot be reached (seed %d)" % [room.id, s])


func test_every_room_is_reachable_from_the_start() -> void:
	for s: int in SEEDS:
		var map: FloorMap = RunGenerator.generate_floor(region, 2, s)
		var seen: Dictionary = {}
		var open: Array[int] = map.start_ids()
		while not open.is_empty():
			var room_id: int = open.pop_back()
			if seen.has(room_id):
				continue
			seen[room_id] = true
			open.append_array(map.next_ids(room_id))
		assert_eq(seen.size(), map.rooms.size(), "seed %d" % s)


func test_paths_never_cross() -> void:
	for s: int in SEEDS:
		var map: FloorMap = RunGenerator.generate_floor(region, 0, s)
		for row: int in map.depth():
			var links: Array[Vector2i] = []
			for room: MapRoom in map.get_row(row):
				for next_id: int in room.next:
					links.append(Vector2i(room.lane, map.get_room(next_id).lane))
			for a: Vector2i in links:
				for b: Vector2i in links:
					assert_false(a.x < b.x and a.y > b.y, "crossing %s %s (seed %d)" % [a, b, s])


func test_some_rooms_offer_more_than_one_door() -> void:
	var branching: int = 0
	var total: int = 0
	for s: int in SEEDS:
		var map: FloorMap = RunGenerator.generate_floor(region, 0, s)
		for row: int in map.depth() - 1:
			for room: MapRoom in map.get_row(row):
				total += 1
				if room.next.size() > 1:
					branching += 1
	assert_gt(float(branching) / total, 0.4, "most floors should offer real choices")


func test_room_type_rules() -> void:
	for s: int in SEEDS:
		var floor_index: int = s % 3
		var map: FloorMap = RunGenerator.generate_floor(region, floor_index, s)
		for room: MapRoom in map.get_row(0):
			assert_eq(room.type, MapRoom.COMBAT, "first row is always a fight")
		for row: int in map.depth():
			var non_fights: Array[StringName] = []
			for room: MapRoom in map.get_row(row):
				assert_false(room.type in [MapRoom.MINI_BOSS, MapRoom.BOSS], "bosses only at the exit")
				if room.type == MapRoom.ELITE:
					assert_gte(row, region.elite_min_row, "no early elites (seed %d)" % s)
				if room.type != MapRoom.COMBAT:
					assert_false(non_fights.has(room.type), "duplicate %s in a row (seed %d)" % [room.type, s])
					non_fights.append(room.type)
		var expected: StringName = MapRoom.BOSS if floor_index == region.floor_count - 1 else MapRoom.MINI_BOSS
		assert_eq(map.exit_room().type, expected)


func test_room_type_mix_roughly_follows_weights() -> void:
	var counts: Dictionary = {}
	var total: int = 0
	for s: int in 400:
		var map: FloorMap = RunGenerator.generate_floor(region, 0, s)
		for row: int in range(region.elite_min_row, map.depth()):
			for room: MapRoom in map.get_row(row):
				counts[room.type] = counts.get(room.type, 0) + 1
				total += 1
	var combat_share: float = float(counts.get(MapRoom.COMBAT, 0)) / total
	assert_between(combat_share, 0.4, 0.65, "about half the rooms are fights")
	for type: StringName in [MapRoom.ELITE, MapRoom.TREASURE, MapRoom.REST, MapRoom.MERCHANT, MapRoom.EVENT]:
		assert_gt(counts.get(type, 0), 0, "%s rooms appear" % type)


func test_zero_weight_types_never_appear() -> void:
	var custom: RegionData = region.duplicate()
	custom.room_weights = {MapRoom.COMBAT: 1.0, MapRoom.REST: 0.0}
	for s: int in 50:
		for room: MapRoom in RunGenerator.generate_floor(custom, 0, s).rooms:
			assert_true(room.type in [MapRoom.COMBAT, MapRoom.MINI_BOSS])


func test_encounters_come_from_the_right_pool() -> void:
	var map: FloorMap = RunGenerator.generate_floor(region, 0, 7)
	for room: MapRoom in map.rooms:
		var encounter: EncounterData = RunGenerator.pick_encounter(region, map, room, 7)
		match room.type:
			MapRoom.COMBAT:
				assert_true(region.combat_encounters.has(encounter))
			MapRoom.ELITE:
				assert_true(region.elite_encounters.has(encounter))
			MapRoom.MINI_BOSS:
				assert_eq(encounter, region.mini_boss_encounter)
			_:
				assert_null(encounter, "%s rooms have no fight" % room.type)
		assert_eq(RunGenerator.pick_encounter(region, map, room, 7), encounter, "seeded")


func test_region_content_is_complete() -> void:
	assert_eq(ContentDB.get_item(&"regions", &"mossy_hollow"), region, "ContentDB indexes the region")
	assert_gt(region.combat_encounters.size(), 1)
	assert_gt(region.elite_encounters.size(), 0)
	assert_not_null(region.mini_boss_encounter)
	assert_not_null(region.boss_encounter)
	for type: StringName in region.room_weights:
		assert_true(MapRoom.TYPE_INFO.has(type), "unknown room type %s" % type)
		assert_false(type in [MapRoom.MINI_BOSS, MapRoom.BOSS], "exits are not rolled")
	var all: Array[EncounterData] = region.combat_encounters + region.elite_encounters
	all.append(region.mini_boss_encounter)
	all.append(region.boss_encounter)
	for encounter: EncounterData in all:
		assert_gt(encounter.waves.size(), 0, str(encounter.id))
		for wave: WaveData in encounter.waves:
			assert_gt(wave.enemies.size(), 0, str(encounter.id))


func _describe(map: FloorMap) -> String:
	var parts: PackedStringArray = []
	for room: MapRoom in map.rooms:
		parts.append("%d:%s>%s" % [room.id, room.type, room.next])
	return ",".join(parts)
