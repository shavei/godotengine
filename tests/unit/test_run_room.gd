extends GutTest
## The run room scene builds the right room for the run's current map room.

const ROOM_SCENE: PackedScene = preload("res://scenes/run/room.tscn")
const TEST_SAVE_DIR: String = "user://test_saves_room"

var region: RegionData
var _original_dir: String
var _original_profile: ProfileState


func before_all() -> void:
	region = load("res://data/regions/region_mossy_hollow.tres")
	# Rooms save the run as they load; keep that away from the real saves.
	_original_dir = SaveManager.save_dir
	_original_profile = GameState.profile
	SaveManager.save_dir = TEST_SAVE_DIR


func before_each() -> void:
	GameState.new_profile()
	# The Healer moves in at Renown 2.
	GameState.admit_villagers(2)


func after_each() -> void:
	GameState.run = null
	SaveManager.delete_slot(GameState.slot)


func after_all() -> void:
	SaveManager.save_dir = _original_dir
	GameState.profile = _original_profile


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
	var spots: Array[InteractSpot] = []
	for child: Node in room.actors.get_children():
		if child is InteractSpot:
			spots.append(child)
	assert_eq(spots.size(), 2)
	assert_true(run.room_cleared, "resting is optional")
	var heal: InteractSpot = spots[0] if spots[0].kind == RunRoom.REST_HEAL else spots[1]
	heal.chosen.emit(heal, room.hero)
	assert_eq(room.hero.health.hp, 80, "30% of 100")
	assert_eq(room.hero.flasks.charges, 1)
	await wait_physics_frames(1)
	for child: Node in room.actors.get_children():
		assert_false(child is InteractSpot and not child.is_queued_for_deletion(), "one comfort only")


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
	# The clear is banked at once: XP from the boss, the run save is gone.
	var summary: RunSummary = boss_room._summary
	assert_not_null(summary)
	assert_true(summary.success)
	assert_eq(summary.xp_gained, 300, "Mother Toad (100) and the Warden (200) were cleared in rooms")
	assert_null(GameState.run)
	assert_false(SaveManager.has_run(GameState.slot))
	assert_eq(GameState.profile.runs_won, 1)
	assert_true(SaveManager.has_save(GameState.slot), "the profile is saved")


func _boss_room_cleared() -> RunRoom:
	var run: RunState = RunState.start(region, 5)
	for i: int in 2:
		_walk_to_exit(run)
		run.mark_cleared()
		run.advance_floor()
	_walk_to_exit(run)
	var room: RunRoom = await _spawn_room(run)
	room.director.room_cleared.emit()
	await wait_physics_frames(1)
	return room


func _orbs(room: RunRoom) -> Array[InteractSpot]:
	var result: Array[InteractSpot] = []
	for spot: InteractSpot in room._offers():
		if spot.kind == RunRoom.POWER_ORB and spot.enabled:
			result.append(spot)
	return result


func test_the_region_boss_leaves_two_power_orbs() -> void:
	var room: RunRoom = await _boss_room_cleared()
	var state: HeroState = GameState.hero_state(0)
	var orbs: Array[InteractSpot] = _orbs(room)
	assert_eq(orbs.size(), 2)
	assert_eq(orbs.map(func(orb: InteractSpot) -> StringName: return orb.payload), state.power_offer)
	var power: PowerData = ContentDB.get_item(&"powers", orbs[0].payload)
	assert_eq(orbs[0].color, power.color)
	assert_eq(orbs[0].icon_shape, power.icon_shape)
	assert_eq(orbs[0].caption, "%s\n%s\nNew power" % [power.display_name, power.ability_name])
	var saved: ProfileState = ProfileState.from_dict(SaveManager.load_data(GameState.slot))
	assert_eq(saved.hero(0).power_offer, state.power_offer, "the offer is saved with the clear")


func test_taking_an_orb_fades_the_other() -> void:
	var room: RunRoom = await _boss_room_cleared()
	var state: HeroState = GameState.hero_state(0)
	var orbs: Array[InteractSpot] = _orbs(room)
	var taken: StringName = orbs[1].payload
	orbs[1].chosen.emit(orbs[1], room.hero)
	await wait_seconds(0.7)
	assert_eq(state.power_offer, [taken] as Array[StringName])
	assert_eq(room._offers().size(), 0, "both orbs are gone")
	assert_true(room.banner.text.contains("The run is complete"))
	var saved: ProfileState = ProfileState.from_dict(SaveManager.load_data(GameState.slot))
	assert_eq(saved.hero(0).power_offer, [taken] as Array[StringName])


func test_mini_bosses_leave_no_orbs() -> void:
	var run: RunState = RunState.start(region, 5)
	_walk_to_exit(run)
	var room: RunRoom = await _spawn_room(run)
	room.director.room_cleared.emit()
	await wait_physics_frames(1)
	assert_eq(_orbs(room).size(), 0)
	assert_true(GameState.hero_state(0).power_offer.is_empty())


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


func _offers(room: RunRoom) -> Array[InteractSpot]:
	var result: Array[InteractSpot] = []
	for child: Node in room.actors.get_children():
		if child is InteractSpot and not child.is_queued_for_deletion():
			result.append(child)
	return result


## A run whose first room is forced to `type`, entered.
func _run_in(type: StringName, seed_value: int = 5) -> RunState:
	var run: RunState = RunState.start(region, seed_value)
	run.enter(run.next_choices()[0])
	run.current_room().type = type
	return run


func test_enemies_drop_loot_that_goes_to_the_wallet() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	var room: RunRoom = await _spawn_room(run)
	assert_eq(room.hud.loot_label.text.contains("Coins 0"), true, "the HUD shows the wallet")
	var boar: Enemy = Enemy.create(ContentDB.get_item(&"enemies", &"tusk_boar"))
	boar.position = Vector2(200, 200)
	room.actors.add_child(boar)
	room.director._track(boar)
	room.director.tracker.add_alive()
	boar.health.take_damage(999)
	await wait_physics_frames(1)
	var pickups: Array[Pickup] = room._pickups()
	assert_gt(pickups.size(), 0, "a Tusk Boar always drops coins")
	var dropped: int = 0
	for pickup: Pickup in pickups:
		if pickup.currency == Wallet.COINS:
			dropped += pickup.amount
	assert_between(dropped, 3, 5)
	# Walk over them.
	room.hero.global_position = Vector2(200, 200)
	await wait_seconds(0.8)
	assert_eq(room._pickups().size(), 0, "all collected")
	assert_eq(run.wallet(0).amount(Wallet.COINS), dropped)
	assert_true(room.hud.loot_label.text.contains("Coins %d" % dropped))


func test_room_clear_pulls_loot_to_the_hero() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	var room: RunRoom = await _spawn_room(run)
	room.drop_loot({Wallet.COINS: 6, Wallet.WOOD: 2}, Vector2(120, 120))
	room.director.room_cleared.emit()
	await wait_seconds(2.0)
	assert_eq(room._pickups().size(), 0)
	assert_eq(run.wallet(0).amount(Wallet.COINS), 6)
	assert_eq(run.wallet(0).amount(Wallet.WOOD), 2)



func test_pulled_loot_never_circles_the_hero() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	var room: RunRoom = await _spawn_room(run)
	var hero: Hero = room.find_child("Hero", true, false) as Hero
	var pickup: Pickup = Pickup.create(Wallet.COINS, 1)
	var got: Array[bool] = [false]
	pickup.collected.connect(func(_p: Pickup, _h: Hero) -> void: got[0] = true)
	room.add_child(pickup)
	pickup.global_position = hero.global_position + Vector2(100, 0)
	await wait_physics_frames(20)
	# Moving sideways when the pull starts (a pop, or the hero walking past) used to
	# settle into an orbit about 100 px out.
	pickup.velocity = Vector2(0, Pickup.MAX_SPEED)
	pickup.attract()
	await wait_seconds(1.0)
	assert_true(got[0], "the coin reaches the hero")


func test_leaving_scoops_up_loot_left_on_the_floor() -> void:
	var run: RunState = RunState.start(region, 5)
	var room: RunRoom = await _spawn_room(run)
	room.drop_loot({Wallet.SHARDS: 1}, Vector2(600, 150))
	# Walking through a door calls this before the next room loads.
	room.scoop_loot(room.hero)
	assert_eq(run.wallet(0).amount(Wallet.SHARDS), 1)
	assert_eq(room._pickups().size(), 0)


func test_elite_room_uses_an_elite_encounter() -> void:
	var run: RunState = _run_in(MapRoom.ELITE)
	var room: RunRoom = await _spawn_room(run)
	assert_true(region.elite_encounters.has(room.director.encounter))
	await wait_seconds(0.9)
	assert_string_starts_with(room.banner.text, "Elite: ")
	var elites: int = 0
	for node: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		if (node as Enemy).data.is_elite:
			elites += 1
	assert_eq(elites, 1, "one elite plus adds")


func test_treasure_chest_drops_loot() -> void:
	var run: RunState = _run_in(MapRoom.TREASURE)
	var room: RunRoom = await _spawn_room(run)
	assert_true(run.room_cleared, "doors are open at once")
	var offers: Array[InteractSpot] = _offers(room)
	assert_eq(offers.size(), 1)
	assert_eq(offers[0].kind, RunRoom.CHEST)
	offers[0].chosen.emit(offers[0], room.hero)
	await wait_physics_frames(1)
	assert_eq(_offers(room).size(), 0, "opened once")
	var coins: int = 0
	var wood: int = 0
	for pickup: Pickup in room._pickups():
		if pickup.currency == Wallet.COINS:
			coins += pickup.amount
		elif pickup.currency == Wallet.WOOD:
			wood += pickup.amount
	assert_between(coins, 20, 35)
	assert_between(wood, 3, 6)


func test_merchant_sells_each_ware_once_for_coins() -> void:
	var run: RunState = _run_in(MapRoom.MERCHANT)
	run.save_hero(0, 50, 100, 1)
	run.wallet(0).add(Wallet.COINS, 100)
	var room: RunRoom = await _spawn_room(run)
	var wares: Dictionary = {}
	for spot: InteractSpot in _offers(room):
		wares[spot.kind] = spot
	assert_eq(wares.size(), 3)
	var balance: BalanceData = room.hero.balance
	var flask: InteractSpot = wares[RunRoom.WARE_FLASK]
	assert_true(flask.enabled)
	flask.chosen.emit(flask, room.hero)
	assert_eq(room.hero.flasks.charges, 2)
	assert_eq(run.wallet(0).amount(Wallet.COINS), 100 - balance.merchant_flask_price)
	var shard: InteractSpot = wares[RunRoom.WARE_SHARD]
	shard.chosen.emit(shard, room.hero)
	assert_eq(run.wallet(0).amount(Wallet.SHARDS), 1)
	var left: int = 100 - balance.merchant_flask_price - balance.merchant_shard_price
	assert_eq(run.wallet(0).amount(Wallet.COINS), left)
	await wait_physics_frames(1)
	assert_eq(_offers(room).size(), 1, "sold wares are gone")
	var heal: InteractSpot = wares[RunRoom.WARE_HEAL]
	assert_eq(heal.enabled, left >= balance.merchant_heal_price)


func test_merchant_refuses_when_short() -> void:
	var run: RunState = _run_in(MapRoom.MERCHANT)
	run.save_hero(0, 50, 100, 1)
	run.wallet(0).add(Wallet.COINS, 10)
	var room: RunRoom = await _spawn_room(run)
	for spot: InteractSpot in _offers(room):
		assert_false(spot.enabled, "%s is greyed out" % spot.kind)
		spot.refused.emit(spot, room.hero)
	assert_eq(room.sign_label.text, "Not enough coins.")
	assert_eq(run.wallet(0).amount(Wallet.COINS), 10)
	assert_eq(room.hero.flasks.charges, 1)


func test_merchant_does_not_sell_flasks_to_a_full_pouch() -> void:
	var run: RunState = _run_in(MapRoom.MERCHANT)
	run.wallet(0).add(Wallet.COINS, 100)
	var room: RunRoom = await _spawn_room(run)
	for spot: InteractSpot in _offers(room):
		if spot.kind == RunRoom.WARE_FLASK:
			assert_false(spot.enabled)
			spot.chosen.emit(spot, room.hero)
	assert_eq(run.wallet(0).amount(Wallet.COINS), 100)


func test_event_room_offers_its_choices() -> void:
	var run: RunState = _run_in(MapRoom.EVENT)
	var room: RunRoom = await _spawn_room(run)
	assert_not_null(room.room_event)
	assert_true(run.room_cleared, "events are optional")
	assert_eq(room.banner.text, room.room_event.title)
	assert_eq(room.sign_label.text, room.room_event.text)
	var offers: Array[InteractSpot] = _offers(room)
	assert_eq(offers.size(), room.room_event.choices.size())
	# The free way out is always possible; leaving takes nothing.
	var way_out: InteractSpot = offers.back()
	assert_true(way_out.enabled)
	way_out.chosen.emit(way_out, room.hero)
	await wait_physics_frames(1)
	assert_eq(_offers(room).size(), 0, "one choice per event")
	assert_eq(room.hero.health.hp, room.hero.health.max_hp)


func test_mossy_shrine_trades_blood_for_a_shard() -> void:
	var run: RunState = _run_in(MapRoom.EVENT)
	run.region = region.duplicate()
	run.region.events = [ContentDB.get_item(&"events", &"mossy_shrine")] as Array[EventData]
	var room: RunRoom = await _spawn_room(run)
	var offer: InteractSpot = _offers(room)[0]
	offer.chosen.emit(offer, room.hero)
	assert_eq(room.hero.health.hp, 80, "20% of 100 HP")
	room.hero.global_position = offer.global_position
	await wait_seconds(0.8)
	assert_eq(run.wallet(0).amount(Wallet.SHARDS), 1)


func test_wishing_well_toss_needs_coins() -> void:
	var run: RunState = _run_in(MapRoom.EVENT)
	run.region = region.duplicate()
	run.region.events = [ContentDB.get_item(&"events", &"wishing_well")] as Array[EventData]
	var room: RunRoom = await _spawn_room(run)
	var toss: InteractSpot = _offers(room)[0]
	assert_false(toss.enabled, "no coins yet")
	run.wallet(0).add(Wallet.COINS, 25)
	assert_true(toss.enabled, "greys in as soon as the hero can pay")


## Walks the current floor (any path) to its exit room, which is left uncleared.
func _walk_to_exit(run: RunState) -> void:
	while run.current_room() != run.map.exit_room():
		run.enter(run.next_choices()[0])
		if run.current_room() != run.map.exit_room():
			run.mark_cleared()


func test_boss_room_is_an_open_arena_with_a_boss_bar() -> void:
	var run: RunState = RunState.start(region, 5)
	_walk_to_exit(run)
	var room: RunRoom = await _spawn_room(run)
	assert_true(room.map_room.is_boss())
	for x: int in range(1, 23):
		for y: int in range(1, 14):
			assert_false(room.room.is_solid(Vector2i(x, y)), "no pillars in a boss arena")
	await wait_seconds(0.9)
	assert_eq(room.banner.text, "Mini-boss: Mother Toad")
	assert_true(room.hud.boss_panel.visible)
	assert_eq(room.hud.boss_name.text, "Mother Toad")
	var bosses: Array[Node] = get_tree().get_nodes_in_group(Enemy.GROUP)
	assert_eq(bosses.size(), 1)
	var toad: Enemy = bosses[0]
	assert_almost_eq(toad.global_position.distance_to(RunRoom.BOSS_SPAWN), 0.0, 1.0)
	toad.health.take_damage(toad.health.max_hp - 1)
	await wait_seconds(1.5)
	assert_eq(room.banner.text, (toad.data as BossData).enrage_line)
	toad.health.take_damage(1)
	await wait_physics_frames(2)
	assert_false(room.hud.boss_panel.visible, "the bar goes with the boss")


func test_entering_a_room_saves_the_run() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	await _spawn_room(run)
	assert_true(SaveManager.has_run(GameState.slot))
	var saved: Dictionary = SaveManager.load_run(GameState.slot)
	assert_eq(int(saved["room"]), run.current_room_id)
	assert_eq(int(saved["seed"]), 5)


func test_clearing_a_fight_gives_xp() -> void:
	var run: RunState = _run_in(MapRoom.COMBAT)
	var room: RunRoom = await _spawn_room(run)
	room.director.room_cleared.emit()
	await wait_physics_frames(1)
	assert_eq(run.xp_earned(0), 15)


func test_hero_level_and_vigor_raise_max_hp() -> void:
	var hero_state: HeroState = GameState.hero_state(0)
	hero_state.level = 3
	hero_state.attributes[HeroState.VIGOR] = 1
	hero_state.attributes[HeroState.MIGHT] = 2
	var room: RunRoom = await _spawn_room(RunState.start(region, 5))
	assert_eq(room.hero.health.max_hp, 118, "100 + 2 levels x 4 + 1 Vigor x 10")
	assert_eq(room.hero.health.hp, 118)
	assert_almost_eq(room.hero.stats.damage_bonus, 0.06, 0.0001)


func test_hero_hits_count_toward_weapon_mastery() -> void:
	var run: RunState = _run_in(MapRoom.REST)
	var room: RunRoom = await _spawn_room(run)
	var result: DamageResult = DamageResult.new()
	result.amount = 25
	room.hero.hitbox.attack = room.hero.weapon.combo[0]
	room.hero.hitbox.hit_landed.emit(null, result)
	assert_eq(int(run.damage_by_weapon(0)[&"sword"]), 25)


func test_falling_banks_half_the_loot_and_ends_the_run() -> void:
	var run: RunState = _run_in(MapRoom.REST)
	run.wallet(0).add_all({Wallet.COINS: 9, Wallet.WOOD: 3})
	run.add_xp(0, 30)
	var room: RunRoom = await _spawn_room(run)
	watch_signals(EventBus)
	room.hero.health.take_damage(9999)
	await wait_physics_frames(1)
	assert_signal_not_emitted(EventBus, "run_ended", "the Healer's revive token comes first")
	room.hero.grant_iframes(0.0)
	room.hero.health.take_damage(9999)
	await wait_physics_frames(1)
	assert_signal_emitted_with_parameters(EventBus, "run_ended", [false])
	assert_true(room.get_node("%FellLabel").visible)
	assert_null(GameState.run)
	assert_false(SaveManager.has_run(GameState.slot), "a fall cannot be undone by quitting")
	var bank: Wallet = GameState.hero_state(0).bank
	assert_eq(bank.amount(Wallet.COINS), 4)
	assert_eq(bank.amount(Wallet.WOOD), 1)
	assert_eq(GameState.hero_state(0).xp, 30, "XP is kept in full")
	assert_false(room._summary.success)
	assert_eq(GameState.profile.run_count, 1)
	# Leave before the results screen would load over the tests.
	room.free()


func test_quitting_never_saves_more_hp_or_flasks_than_the_hero_has() -> void:
	var run: RunState = _run_in(MapRoom.REST)
	run.save_hero(0, 50, 100, 1)
	var room: RunRoom = await _spawn_room(run)
	# Healing in the Rest room and then quitting must not keep the heal.
	room.hero.health.heal(30)
	room.write_quit_save()
	var carry: Dictionary = SaveManager.load_run(GameState.slot)["heroes"]["0"]["carry"]
	assert_eq(int(carry["hp"]), 50)
	# Losing HP before quitting is kept.
	room.hero.health.take_damage(60)
	room.hero.flasks.charges = 0
	room.write_quit_save()
	carry = SaveManager.load_run(GameState.slot)["heroes"]["0"]["carry"]
	assert_eq(int(carry["hp"]), 20)
	assert_eq(int(carry["flasks"]), 0)


func test_a_quit_run_continues_in_the_same_room() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	run.save_hero(0, 70, 100, 2)
	var room: RunRoom = await _spawn_room(run)
	room.hero.health.take_damage(10)
	room.write_quit_save()
	room.free()
	GameState.run = null
	assert_true(GameState.load_saved_run())
	var again: RunRoom = await _spawn_room(GameState.run)
	assert_eq(again.run.current_room_id, run.current_room_id)
	assert_eq(again.map_room.type, run.current_room().type)
	assert_eq(again.hero.health.hp, 60)
	assert_eq(again.hero.flasks.charges, 2)


# --- Village services (M4 PR 2) ----------------------------------------------------

func test_a_new_run_gets_the_village_services() -> void:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(&"farmer"), &"growth")
	var room: RunRoom = await _spawn_room(_run_in(MapRoom.REST))
	var balance: BalanceData = room.hero.balance
	assert_eq(room.hero.flasks.max_charges, balance.flask_charges + 3, "base +1, Growth Farmer +2")
	assert_eq(room.hero.flasks.charges, room.hero.flasks.max_charges)
	assert_eq(room.hero.revives, 1, "the Healer's token")
	assert_true(room.hud.flask_label.text.ends_with("Revive 1"), room.hud.flask_label.text)


func test_revive_tokens_and_clean_rooms_carry_through_doors_and_quits() -> void:
	var run: RunState = _run_in(MapRoom.REST)
	var room: RunRoom = await _spawn_room(run)
	room.hero.health.take_damage(9999)
	assert_eq(room.hero.revives, 0, "used up")
	room.write_quit_save()
	var carry: Dictionary = SaveManager.load_run(GameState.slot)["heroes"]["0"]["carry"]
	assert_eq(int(carry["revives"]), 0, "quitting does not give the token back")
	run.save_hero(0, 40, 100, 2, 0, 3)
	room.free()
	room = await _spawn_room(run)
	assert_eq(room.hero.revives, 0, "the next room remembers")
	assert_eq(room._clean_rooms, 3)


func test_boss_rooms_switch_on_the_frost_salve() -> void:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(&"healer"), &"frost")
	var room: RunRoom = await _spawn_room(_run_in(MapRoom.REST))
	assert_eq(room.hero.stats.damage_taken_multiplier, 1.0)
	room.free()
	var run: RunState = _run_in(MapRoom.MINI_BOSS)
	room = await _spawn_room(run)
	assert_almost_eq(room.hero.stats.damage_taken_multiplier, 0.9, 0.001)
	room.free()


func test_a_cleared_fight_heals_and_grows_mending_gear() -> void:
	var village: VillageState = GameState.profile.village
	GiftSystem.give(village, village.index_of(&"healer"), &"growth")
	GiftSystem.give(village, village.index_of(&"smith"), &"growth")
	GameState.hero_state(0).bought_services.append(&"smith_growth")
	var room: RunRoom = await _spawn_room(_run_in(MapRoom.REST))
	room.hero.health.take_damage(20)
	room._hit_this_room = false
	room._apply_room_services()
	assert_eq(room.hero.health.hp, 83, "Growth Healer heals 3")
	assert_eq(room._clean_rooms, 1, "no hit since the room began")
	assert_almost_eq(room.hero.stats.damage_bonus, 0.05, 0.001)
	room.hero.grant_iframes(0.0)
	room.hero.health.take_damage(1)
	assert_eq(room._clean_rooms, 0, "a hit resets the gear")
	assert_eq(room.hero.stats.damage_bonus, 0.0)
	room._apply_room_services()
	assert_eq(room._clean_rooms, 0, "this room had a hit")


func test_skip_room_clears_a_fight_at_once() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	var room: RunRoom = await _spawn_room(run)
	await wait_physics_frames(60)
	assert_true(room.skip_room())
	await wait_physics_frames(1)
	assert_true(run.room_cleared)
	assert_eq(get_tree().get_nodes_in_group(Enemy.GROUP).size(), 0)
	for door: RoomDoor in _doors(room):
		assert_false(door.locked)
	assert_false(room.skip_room(), "clear already")


func test_a_fall_names_what_hit_the_hero_last() -> void:
	var run: RunState = RunState.start(region, 5)
	run.enter(run.next_choices()[0])
	var room: RunRoom = await _spawn_room(run)
	var boar: Enemy = Enemy.create(ContentDB.get_item(&"enemies", &"tusk_boar"))
	room.actors.add_child(boar)
	await wait_physics_frames(1)
	room.hero.hurtbox.last_hitbox = boar.hitbox
	room.hero.revives = 0
	watch_signals(EventBus)
	room.hero.health.take_damage(10000)
	await wait_physics_frames(1)
	assert_signal_emitted(EventBus, "run_summarized")
	var summary: RunSummary = get_signal_parameters(EventBus, "run_summarized")[0]
	assert_false(summary.success)
	assert_eq(summary.death_cause, "tusk_boar")
	assert_eq(summary.region_id, &"mossy_hollow")
	assert_eq(summary.route, run.route)
	assert_eq(summary.route.size(), 1)
	assert_true(summary.route[0].begins_with("1:"))
