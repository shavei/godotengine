extends Control
## Placeholder title screen for M0. Real menu (Continue, New Game, Seasons, ...) comes later.


func _ready() -> void:
	%Version.text = "v%s  |  Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.1"),
		Engine.get_version_info()["string"],
	]
