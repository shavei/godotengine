extends Control
## Placeholder title screen. Real menu (Continue, New Game, Seasons, ...) comes later.
## For now it starts a Mossy Hollow run, or opens the M1 combat test room or wave room.

const RUN_ROOM_SCENE: String = "res://scenes/run/room.tscn"
## Until the village gate exists (M4), runs start in the first region.
const START_REGION: StringName = &"mossy_hollow"
const TEST_ROOM_SCENE: String = "res://scenes/run/test_room.tscn"
const WAVE_ROOM_SCENE: String = "res://scenes/run/wave_room.tscn"


func _ready() -> void:
	%Version.text = "v%s  |  Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.1"),
		Engine.get_version_info()["string"],
	]
	%RunButton.pressed.connect(_on_run_pressed)
	%PlayButton.pressed.connect(_on_play_pressed)
	%WaveButton.pressed.connect(_on_wave_pressed)
	%RunButton.grab_focus()


func _on_run_pressed() -> void:
	var region: RegionData = ContentDB.get_item(&"regions", START_REGION) as RegionData
	var seed_value: int = randi()
	GameState.run = RunState.start(region, seed_value)
	EventBus.run_started.emit(region.id, seed_value)
	SceneRouter.go(RUN_ROOM_SCENE)


func _on_play_pressed() -> void:
	SceneRouter.go(TEST_ROOM_SCENE)


func _on_wave_pressed() -> void:
	SceneRouter.go(WAVE_ROOM_SCENE)
