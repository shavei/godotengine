extends Node2D
## Tuning room: a safe place to tune combat feel with a controller.
## Start (or Esc) opens the tuning menu, which pauses the game. The menu can spawn a
## round of Mossy Hollow enemies or one of its bosses, turn powers on and off (up to the
## 3 kept slots, like a real hero), save the results, or go back to the title.

const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const RESPAWN_DELAY: float = 1.5
const REGION: String = "res://data/regions/region_mossy_hollow.tres"
## Powers the menu can try, in menu order.
const TRY_POWERS: Array[StringName] = [&"fire", &"frost", &"stone", &"growth"]

@onready var hero: Hero = $Actors/Hero
@onready var hud: Hud = $Hud
@onready var camera: GameCamera = $Camera
@onready var room: PlaceholderRoom = $Room
@onready var director: WaveDirector = $WaveDirector
@onready var wave_label: Label = %WaveLabel

## The scene's own encounter (the test waves); the boss actions swap in the region's.
var _test_waves: EncounterData
## A stand-in hero for trying powers; slot rules come from GiftSystem.
var _trial: HeroState = HeroState.new()


func _ready() -> void:
	hud.bind_hero(hero)
	$Overlay/Help.text = "Tuning menu %s    Attack %s    Dodge %s    Powers %s, %s, %s" % [
		InputBindings.hint(&"pause"), InputBindings.hint(&"attack"), InputBindings.hint(&"dodge"),
		InputBindings.hint(&"power_1"), InputBindings.hint(&"power_2"), InputBindings.hint(&"power_3")]
	var bounds: Rect2 = room.get_rect()
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	EventBus.hero_died.connect(_on_hero_died)
	director.wave_started.connect(_on_wave_started)
	director.room_cleared.connect(_on_room_cleared)
	director.enemy_spawned.connect(_on_enemy_spawned)
	_test_waves = director.encounter


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		open_menu()


func open_menu() -> void:
	var actions: Array[Array] = [
		["Spawn enemies", spawn_enemies],
		["Fight Mother Toad", fight_boss.bind(false)],
		["Fight Warden of Roots", fight_boss.bind(true)],
	]
	for power_id: StringName in TRY_POWERS:
		var power: PowerData = ContentDB.get_item(&"powers", power_id) as PowerData
		if power != null:
			var state: String = "on" if GiftSystem.find(_trial, power_id) != null else "off"
			actions.append(["%s (%s): %s" % [power.display_name, power.ability_name, state], toggle_power.bind(power_id)])
	actions.append(["Back to title", _go_to_title])
	TuningPanel.open(actions)


## Puts a power in the next free slot, or takes it out if it is already there.
func toggle_power(power_id: StringName) -> void:
	if GiftSystem.find(_trial, power_id) != null:
		GiftSystem.release(_trial, power_id)
	elif GiftSystem.keep(_trial, power_id, hero.balance) == null:
		TuningPanel.status_text = "All %d slots are full. Turn a power off first." % GiftSystem.slot_count(hero.balance)
	hero.equip_powers(_trial.kept_powers)
	open_menu()


## Starts the Mossy Hollow test waves, unless enemies are already out.
func spawn_enemies() -> void:
	_fight(_test_waves)


## Starts the Mossy Hollow mini-boss, or its region boss with `region_boss`.
func fight_boss(region_boss: bool) -> void:
	var region: RegionData = load(REGION)
	_fight(region.boss_encounter if region_boss else region.mini_boss_encounter)


func _fight(encounter: EncounterData) -> void:
	if director.tracker != null and not director.is_room_cleared():
		TuningPanel.status_text = "Enemies are already out."
		return
	TuningPanel.close()
	director.encounter = encounter
	director.start()


func _on_enemy_spawned(enemy: Enemy) -> void:
	if enemy.data is BossData:
		hud.bind_boss(enemy)


func _on_wave_started(index: int, total: int) -> void:
	wave_label.text = "Wave %d / %d" % [index + 1, total]


func _on_room_cleared() -> void:
	wave_label.text = "Clear! Start: menu to spawn more"


func _on_hero_died(_player_id: int) -> void:
	%FellLabel.show()
	# A signal connection (not await) so nothing runs if the room is left first.
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_restart)


func _restart() -> void:
	SceneRouter.go(scene_file_path)


func _go_to_title() -> void:
	TuningPanel.close()
	SceneRouter.go(TITLE_SCENE)
