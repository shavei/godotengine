extends Control
## Placeholder title screen. Real menu (Continue, New Game, Seasons, ...) comes later.
## For now it offers the M1 combat test room and the wave room.

const TEST_ROOM_SCENE: String = "res://scenes/run/test_room.tscn"
const WAVE_ROOM_SCENE: String = "res://scenes/run/wave_room.tscn"


func _ready() -> void:
	%Version.text = "v%s  |  Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.1"),
		Engine.get_version_info()["string"],
	]
	%PlayButton.pressed.connect(_on_play_pressed)
	%WaveButton.pressed.connect(_on_wave_pressed)
	%PlayButton.grab_focus()


func _on_play_pressed() -> void:
	SceneRouter.go(TEST_ROOM_SCENE)


func _on_wave_pressed() -> void:
	SceneRouter.go(WAVE_ROOM_SCENE)
