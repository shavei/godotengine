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
	assert_eq(run.hero_snapshot(0), {"hp": 55, "max_hp": 100, "flasks": 2})
	assert_eq(run.hero_snapshot(1), {}, "keyed by player_id")
