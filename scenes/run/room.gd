class_name RunRoom
extends Node2D
## One room of a run (docs/GDD.md Section 6). Reads GameState.run, builds the room for
## the current map room, and opens doors to the next rooms once it is done. Every door
## loads this same scene again for the room behind it.
##
## Fights use a WaveDirector encounter. Rest rooms offer a heal or a flask. Treasure,
## Merchant and Event rooms are signposts until M2 PR 2. Playing this scene on its own
## (F6) starts a test run.

const ROOM_SCENE: String = "res://scenes/run/room.tscn"
const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const DEFAULT_REGION: StringName = &"mossy_hollow"
const HERO_START: Vector2 = Vector2(384, 400)
const RUN_OVER_DELAY: float = 2.5
const BANNER_TIME: float = 1.4
const REST_HEAL: StringName = &"heal"
const REST_FLASK: StringName = &"flask"

## Pillar layouts for fight rooms, in tiles. Picked per room from the run seed.
const FIGHT_LAYOUTS: Array[Array] = [
	[Vector2i(6, 4), Vector2i(17, 4), Vector2i(6, 10), Vector2i(17, 10)],
	[Vector2i(11, 5), Vector2i(12, 5), Vector2i(11, 9), Vector2i(12, 9)],
	[Vector2i(4, 7), Vector2i(8, 4), Vector2i(15, 4), Vector2i(19, 7)],
	[],
]
const SPAWN_POINTS: Array[Vector2] = [
	Vector2(96, 96), Vector2(384, 96), Vector2(672, 96), Vector2(96, 384), Vector2(672, 384),
	Vector2(80, 240), Vector2(688, 240), Vector2(288, 176), Vector2(480, 304), Vector2(288, 304), Vector2(480, 176),
]
const PLACEHOLDER_TEXT: Dictionary = {
	MapRoom.TREASURE: "A treasure room will be here soon.\nFor now, catch your breath and pick a door.",
	MapRoom.MERCHANT: "A merchant will set up shop here soon.\nFor now, pick a door.",
	MapRoom.EVENT: "Something curious will happen here soon.\nFor now, pick a door.",
}

var run: RunState
var map_room: MapRoom

var _leaving: bool = false

@onready var hero: Hero = $Actors/Hero
@onready var hud: Hud = $Hud
@onready var camera: GameCamera = $Camera
@onready var room: PlaceholderRoom = $Room
@onready var actors: Node2D = $Actors
@onready var doors: Node2D = $Doors
@onready var director: WaveDirector = $WaveDirector
@onready var run_map: RunMap = $RunMap
@onready var room_label: Label = %RoomLabel
@onready var wave_label: Label = %WaveLabel
@onready var banner: Label = %Banner
@onready var sign_label: Label = %SignLabel


func _ready() -> void:
	run = GameState.run
	if run == null:
		run = _start_test_run()
	map_room = run.current_room()
	hero.global_position = HERO_START
	_restore_hero()
	hud.bind_hero(hero)
	room.floor_a = run.region.floor_color
	room.floor_b = run.region.floor_color.darkened(0.08)
	_fit_camera()
	EventBus.hero_died.connect(_on_hero_died)
	director.wave_started.connect(_on_wave_started)
	director.room_cleared.connect(_on_room_cleared)
	room_label.text = _room_title()
	run_map.show_run(run, run.is_in_corridor())
	if run.is_in_corridor():
		_setup_corridor()
	elif map_room.is_fight():
		_setup_fight()
	elif map_room.type == MapRoom.REST:
		_setup_rest()
	else:
		_setup_signpost()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		_leave_run()
	elif event.is_action_pressed(&"interact") and run.is_run_won() and not _leaving:
		_leave_run()


# --- Room setups ------------------------------------------------------------

func _setup_corridor() -> void:
	room.set_pillars([] as Array[Vector2i])
	wave_label.text = ""
	_show_banner("%s\nFloor %d" % [run.region.display_name, run.floor_index + 1], BANNER_TIME * 1.5)
	sign_label.text = "Pick a door. The sign shows what waits behind it.\nTab / Back shows the map."
	_open_exits()


func _setup_fight() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run.run_seed, run.floor_index, map_room.id, &"layout"])
	var pillars: Array[Vector2i] = []
	pillars.assign(FIGHT_LAYOUTS[rng.randi_range(0, FIGHT_LAYOUTS.size() - 1)])
	room.set_pillars(pillars)
	director.spawn_points = _free_spawn_points()
	director.rng_seed = hash([run.run_seed, run.floor_index, map_room.id, &"spawns"])
	director.rng.seed = director.rng_seed
	director.encounter = RunGenerator.pick_encounter(run.region, run.map, map_room, run.run_seed)
	_show_locked_doors()
	director.start()


func _setup_rest() -> void:
	room.set_pillars([] as Array[Vector2i])
	wave_label.text = "Rest"
	sign_label.text = "A quiet spot. Take one comfort, then pick a door."
	var heal_percent: int = roundi(hero.balance.rest_heal_fraction * 100.0)
	var offers: Array[RestSpot] = [
		RestSpot.create(REST_HEAL, "Heal %d%%" % heal_percent, Color(0.45, 0.85, 0.5)),
		RestSpot.create(REST_FLASK, "+%d flask" % hero.balance.rest_flask_refill, Color(0.95, 0.5, 0.55)),
	]
	for i: int in offers.size():
		offers[i].position = Vector2(304.0 + i * 160.0, 250.0)
		offers[i].chosen.connect(_on_rest_chosen)
		actors.add_child(offers[i])
	run.mark_cleared()
	_open_exits()


func _setup_signpost() -> void:
	room.set_pillars([] as Array[Vector2i])
	wave_label.text = MapRoom.type_name(map_room.type)
	sign_label.text = PLACEHOLDER_TEXT.get(map_room.type, "")
	run.mark_cleared()
	_open_exits()


# --- Doors ------------------------------------------------------------------

## Fights show their exits barred until the room is clear.
func _show_locked_doors() -> void:
	if map_room == run.map.exit_room():
		return
	_place_doors(map_room.next, true)


func _open_exits() -> void:
	_clear_doors()
	if run.is_run_won():
		_finish_run()
	elif run.is_floor_done():
		var stairs: RoomDoor = RoomDoor.create(-1, MapRoom.COMBAT, "Down to floor %d" % (run.floor_index + 2), false)
		stairs.position = Vector2(room.get_rect().size.x * 0.5, room.tile_size)
		stairs.entered.connect(_on_door_entered)
		doors.add_child(stairs)
	else:
		_place_doors(run.next_choices(), false)


func _place_doors(room_ids: Array[int], locked: bool) -> void:
	_clear_doors()
	var inner: Rect2 = room.get_inner_rect()
	var sorted: Array[MapRoom] = []
	for room_id: int in room_ids:
		sorted.append(run.map.get_room(room_id))
	sorted.sort_custom(func(a: MapRoom, b: MapRoom) -> bool: return a.lane < b.lane)
	for i: int in sorted.size():
		var target: MapRoom = sorted[i]
		var door: RoomDoor = RoomDoor.create(target.id, target.type, MapRoom.type_name(target.type), locked)
		var x: float = inner.position.x + inner.size.x * (i + 0.5) / sorted.size()
		door.position = Vector2(snappedf(x - room.tile_size * 0.5, room.tile_size) + room.tile_size * 0.5, room.tile_size)
		door.entered.connect(_on_door_entered)
		doors.add_child(door)


func _clear_doors() -> void:
	for child: Node in doors.get_children():
		doors.remove_child(child)
		child.queue_free()


func _on_door_entered(door: RoomDoor) -> void:
	if _leaving:
		return
	_leaving = true
	run.save_hero(hero.player_id, hero.health.hp, hero.health.max_hp, hero.flasks.charges)
	if door.room_id < 0:
		run.advance_floor()
	else:
		run.enter(door.room_id)
	SceneRouter.go(ROOM_SCENE)


# --- Events -----------------------------------------------------------------

func _on_wave_started(index: int, total: int) -> void:
	wave_label.text = "Wave %d / %d" % [index + 1, total]
	if index == 0:
		_show_banner(MapRoom.type_name(map_room.type), BANNER_TIME)


func _on_room_cleared() -> void:
	wave_label.text = "Room clear"
	run.mark_cleared()
	if not run.is_run_won():
		_show_banner("Room clear!", BANNER_TIME)
	_open_exits()


func _on_rest_chosen(spot: RestSpot, who: Hero) -> void:
	if spot.kind == REST_HEAL:
		who.health.heal(roundi(who.health.max_hp * who.balance.rest_heal_fraction))
	else:
		who.flasks.refill(who.balance.rest_flask_refill)
	for child: Node in actors.get_children():
		if child is RestSpot:
			child.queue_free()
	sign_label.text = "Feeling better. Pick a door."


func _finish_run() -> void:
	EventBus.run_ended.emit(true)
	sign_label.text = ""
	_show_banner("%s cleared!\nThe run is complete.\nShift / B to return" % run.region.display_name, 0.0)


func _on_hero_died(_player_id: int) -> void:
	if _leaving:
		return
	_leaving = true
	EventBus.run_ended.emit(false)
	GameState.run = null
	%FellLabel.show()
	# A signal connection (not await) so nothing runs if the room is left first.
	get_tree().create_timer(RUN_OVER_DELAY).timeout.connect(SceneRouter.go.bind(TITLE_SCENE))


func _leave_run() -> void:
	_leaving = true
	GameState.run = null
	SceneRouter.go(TITLE_SCENE)


# --- Helpers ----------------------------------------------------------------

func _start_test_run() -> RunState:
	var region: RegionData = ContentDB.get_item(&"regions", DEFAULT_REGION) as RegionData
	var test_run: RunState = RunState.start(region, randi())
	GameState.run = test_run
	return test_run


func _restore_hero() -> void:
	var snapshot: Dictionary = run.hero_snapshot(hero.player_id)
	if snapshot.is_empty():
		return
	hero.health.hp = clampi(snapshot["hp"], 1, hero.health.max_hp)
	hero.flasks.charges = clampi(snapshot["flasks"], 0, hero.flasks.max_charges)


func _room_title() -> String:
	var where: String = "Corridor" if map_room == null else MapRoom.type_name(map_room.type)
	return "Floor %d / %d   %s" % [run.floor_index + 1, run.region.floor_count, where]


## Spawn points that are not inside a pillar of the chosen layout.
func _free_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for point: Vector2 in SPAWN_POINTS:
		if not room.is_solid(Vector2i(point / room.tile_size)):
			points.append(point)
	return points


func _fit_camera() -> void:
	var bounds: Rect2 = room.get_rect()
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.global_position = hero.global_position
	camera.reset_smoothing()


func _show_banner(text: String, duration: float) -> void:
	banner.text = text
	banner.show()
	banner.modulate.a = 1.0
	if duration > 0.0:
		var tween: Tween = create_tween()
		tween.tween_interval(duration)
		tween.tween_property(banner, "modulate:a", 0.0, 0.3)
