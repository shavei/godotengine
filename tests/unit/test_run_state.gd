extends GutTest
## Moving through a run (RunState).

var region: RegionData


func before_all() -> void:
	region = load("res://data/regions/region_mossy_hollow.tres")


func test_run_starts_in_the_first_floor_corridor() -> void:
	var run: RunState = RunState.start(region, 42)
	assert_eq(run.floor_index, 0)
	assert_true(run.is_in_corridor())
	assert_null(run.current_room())
	assert_eq(run.next_choices(), run.map.start_ids())


func test_only_linked_rooms_can_be_entered() -> void:
	var run: RunState = RunState.start(region, 42)
	var exit_id: int = run.map.exit_room().id
	assert_false(run.enter(exit_id), "cannot skip to the exit")
	var first: int = run.next_choices()[0]
	assert_true(run.enter(first))
	assert_eq(run.current_room_id, first)
	assert_eq(run.path, [first] as Array[int])


func test_choices_open_only_after_a_clear() -> void:
	var run: RunState = RunState.start(region, 42)
	run.enter(run.next_choices()[0])
	assert_eq(run.next_choices(), [] as Array[int])
	run.mark_cleared()
	assert_eq(run.next_choices(), run.current_room().next)
	assert_eq(run.rooms_cleared, 1)
	run.mark_cleared()
	assert_eq(run.rooms_cleared, 1, "clearing twice counts once")


func test_walking_a_full_run_reaches_the_boss() -> void:
	var run: RunState = RunState.start(region, 9)
	var floors_seen: Array[int] = []
	while not run.is_run_won():
		if run.is_floor_done():
			floors_seen.append(run.floor_index)
			assert_true(run.advance_floor())
			assert_true(run.is_in_corridor())
			continue
		assert_true(run.enter(run.next_choices().back()))
		run.mark_cleared()
	floors_seen.append(run.floor_index)
	assert_eq(floors_seen, [0, 1, 2] as Array[int])
	assert_eq(run.current_room().type, MapRoom.BOSS)
	assert_false(run.advance_floor(), "no floor after the boss")


func test_cannot_advance_before_the_exit_is_cleared() -> void:
	var run: RunState = RunState.start(region, 3)
	assert_false(run.advance_floor())
	assert_eq(run.floor_index, 0)


func test_hero_snapshot_round_trip() -> void:
	var run: RunState = RunState.start(region, 1)
	assert_eq(run.hero_snapshot(0), {})
	run.save_hero(0, 55, 100, 2)
	assert_eq(run.hero_snapshot(0), {"hp": 55, "max_hp": 100, "flasks": 2, "revives": 0, "clean_rooms": 0,
			"floor": -1, "free_flasks": 0})
	assert_eq(run.hero_snapshot(1), {}, "keyed by player_id")


func _mid_run() -> RunState:
	var run: RunState = RunState.start(region, 77)
	run.enter(run.next_choices()[0])
	run.mark_cleared()
	run.enter(run.next_choices()[-1])
	run.save_hero(0, 61, 104, 2, 0, 0, 0, 1)
	run.wallet(0).add_all({Wallet.COINS: 12, Wallet.WOOD: 3})
	run.add_xp(0, 30)
	run.add_weapon_damage(0, &"sword", 450)
	run.elapsed = 93.5
	return run


func test_mid_run_save_round_trips_through_json() -> void:
	var run: RunState = _mid_run()
	var parsed: Variant = JSON.parse_string(JSON.stringify(run.to_dict()))
	var loaded: RunState = RunState.from_dict(parsed, region)
	assert_not_null(loaded)
	assert_eq(loaded.run_seed, 77)
	assert_eq(loaded.floor_index, 0)
	assert_eq(loaded.current_room_id, run.current_room_id)
	assert_eq(loaded.path, run.path)
	assert_eq(loaded.route, run.route)
	assert_eq(loaded.route.size(), 2, "the route keeps every room entered (metrics)")
	assert_false(loaded.room_cleared, "the room starts over")
	assert_eq(loaded.rooms_cleared, 1)
	assert_almost_eq(loaded.elapsed, 93.5, 0.001)
	assert_eq(loaded.hero_snapshot(0), {"hp": 61, "max_hp": 104, "flasks": 2, "revives": 0, "clean_rooms": 0, "floor": 0, "free_flasks": 1})
	assert_eq(loaded.wallet(0).amount(Wallet.COINS), 12)
	assert_eq(loaded.xp_earned(0), 30)
	assert_eq(int(loaded.damage_by_weapon(0)[&"sword"]), 450)
	assert_eq(loaded.to_dict(), run.to_dict(), "saving again gives the same data")
	# The map is rebuilt from the seed, so the doors are the same.
	loaded.mark_cleared()
	run.mark_cleared()
	assert_eq(loaded.next_choices(), run.next_choices())


func test_mid_run_save_keeps_the_floor() -> void:
	var run: RunState = RunState.start(region, 5)
	while run.current_room() != run.map.exit_room():
		run.enter(run.next_choices()[0])
		run.mark_cleared()
	assert_true(run.advance_floor())
	var loaded: RunState = RunState.from_dict(run.to_dict(), region)
	assert_eq(loaded.floor_index, 1)
	assert_true(loaded.is_in_corridor())
	assert_eq(loaded.map.rows.size(), run.map.rows.size())


func test_saved_run_for_another_region_or_a_missing_room_is_refused() -> void:
	var data: Dictionary = _mid_run().to_dict()
	var other: RegionData = region.duplicate()
	other.id = &"somewhere_else"
	assert_null(RunState.from_dict(data, other))
	assert_null(RunState.from_dict(data, null))
	data["room"] = 9999
	assert_null(RunState.from_dict(data, region))


func test_route_spans_floors() -> void:
	var run: RunState = RunState.start(region, 42)
	while not run.is_floor_done():
		run.enter(run.next_choices()[0])
		run.mark_cleared()
	run.advance_floor()
	run.enter(run.next_choices()[0])
	assert_eq(run.path.size(), 1, "the path is this floor's")
	assert_gt(run.route.size(), 2)
	assert_true(run.route[0].begins_with("1:"))
	assert_true(run.route.back().begins_with("2:"))
	assert_eq(run.route[run.route.size() - 2], "1:%s" % MapRoom.MINI_BOSS, "floor 1 ends at its mini-boss")
