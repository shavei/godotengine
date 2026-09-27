extends GutTest
## The run room scene builds the right room for the run's current map room.

const ROOM_SCENE: PackedScene = preload("res://scenes/run/room.tscn")

var region: RegionData


func before_all() -> void:
	region = load("res://data/regions/region_mossy_hollow.tres")


func after_each() -> void:
	GameState.run = null


func _spawn_room(run: RunState) -> RunRoom:
	GameState.run = run
	var room: RunRoom = ROOM_SCENE.instantiate()
	add_child_autofree(room)
	await wait_physics_frames(3)
	return room


func _doors(room: RunRoom) -> Array[RoomDoor]:
	var result: Array[RoomDoor] = []
	for child: Node in room.doors.get_children():
		if child is RoomDoor and not child.is_queued_for_deletion():
			result.append(child)
	return result


func test_corridor_opens_a_door_per_first_room() -> void:
	var run: RunState = RunState.start(region, 5)
	var room: RunRoom = await _spawn_room(run)
	var doors: Array[RoomDoor] = _doors(room)
	assert_eq(doors.size(), run.map.start_ids().size())
	for door: RoomDoor in doors:
		assert_false(door.locked)
		assert_true(run.map.start_ids().has(door.room_id))
	assert_true(room.run_map.is_open(), "the map starts open in the corridor")
	assert_eq(room.room_label.text, "Floor 1 / 3   Corridor")


func test_doors_follow_map_lanes_left_to_right() -> void:
	var run: RunState = RunState.start(region, 5)
	var room: RunRoom = await _spawn_room(run)
	var doors: Array[RoomDoor] = _doors(room)
	for i: int in range(1, doors.size()):
		assert_lt(doors[i - 1].position.x, doors[i].position.x)
		assert_lt(run.map.get_room(doors[i - 1].room_id).lane, run.map.get_room(doors[i].room_id).lane)


func test_fight_room_bars_doors_until_clear() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	var room: RunRoom = await _spawn_room(run)
	assert_eq(room.director.tracker.current_wave, 0, "the encounter started")
	assert_true(region.combat_encounters.has(room.director.encounter))
	var doors: Array[RoomDoor] = _doors(room)
	assert_eq(doors.size(), run.current_room().next.size())
	for door: RoomDoor in doors:
		assert_true(door.locked)
	room.director.room_cleared.emit()
	await wait_physics_frames(1)
	assert_true(run.room_cleared)
	for door: RoomDoor in _doors(room):
		assert_false(door.locked)


func test_rest_room_offers_heal_or_flask() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	run.current_room().type = MapRoom.REST
	run.save_hero(0, 50, 100, 1)
	var room: RunRoom = await _spawn_room(run)
	var spots: Array[RestSpot] = []
	for child: Node in room.actors.get_children():
		if child is RestSpot:
			spots.append(child)
	assert_eq(spots.size(), 2)
	assert_true(run.room_cleared, "resting is optional")
	var heal: RestSpot = spots[0] if spots[0].kind == RunRoom.REST_HEAL else spots[1]
	heal.chosen.emit(heal, room.hero)
	assert_eq(room.hero.health.hp, 80, "30% of 100")
	assert_eq(room.hero.flasks.charges, 1)
	await wait_physics_frames(1)
	for child: Node in room.actors.get_children():
		assert_false(child is RestSpot and not child.is_queued_for_deletion(), "one comfort only")


func test_hero_keeps_hp_and_flasks_between_rooms() -> void:
	var run: RunState = RunState.start(region, 5)
	run.save_hero(0, 40, 100, 1)
	var room: RunRoom = await _spawn_room(run)
	assert_eq(room.hero.health.hp, 40)
	assert_eq(room.hero.flasks.charges, 1)
	assert_eq(room.hud.hp_label.text, "40 / 100")


func test_floor_exit_leads_down_and_the_boss_ends_the_run() -> void:
	var run: RunState = RunState.start(region, 5)
	_walk_to_exit(run)
	var room: RunRoom = await _spawn_room(run)
	assert_eq(room.director.encounter, region.mini_boss_encounter)
	room.director.room_cleared.emit()
	await wait_physics_frames(1)
	var doors: Array[RoomDoor] = _doors(room)
	assert_eq(doors.size(), 1)
	assert_eq(doors[0].room_id, -1, "stairs to the next floor")
	room.queue_free()
	await wait_physics_frames(1)
	assert_true(run.advance_floor())
	_walk_to_exit(run)
	run.mark_cleared()
	assert_true(run.advance_floor())
	_walk_to_exit(run)
	assert_eq(run.floor_index, 2)
	var boss_room: RunRoom = await _spawn_room(run)
	assert_eq(boss_room.director.encounter, region.boss_encounter)
	watch_signals(EventBus)
	boss_room.director.room_cleared.emit()
	await wait_physics_frames(1)
	assert_true(run.is_run_won())
	assert_signal_emitted_with_parameters(EventBus, "run_ended", [true])
	assert_eq(_doors(boss_room).size(), 0)


func test_open_door_reports_the_hero_walking_in() -> void:
	var world: Node2D = Node2D.new()
	add_child_autofree(world)
	var door: RoomDoor = RoomDoor.create(3, MapRoom.REST, "Rest", true)
	world.add_child(door)
	var hero: Hero = load("res://scenes/actors/hero/hero.tscn").instantiate()
	hero.position = Vector2(0, 5)
	world.add_child(hero)
	watch_signals(door)
	await wait_physics_frames(4)
	assert_signal_not_emitted(door, "entered", "locked doors stay shut")
	door.locked = false
	await wait_physics_frames(4)
	assert_signal_emit_count(door, "entered", 1)


## Walks the current floor (any path) to its exit room, which is left uncleared.
func _walk_to_exit(run: RunState) -> void:
	while run.current_room() != run.map.exit_room():
		run.enter(run.next_choices()[0])
		if run.current_room() != run.map.exit_room():
			run.mark_cleared()
