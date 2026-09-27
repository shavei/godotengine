extends Node
## Boot scene. Autoloads (ContentDB, SaveManager, ...) are ready before this runs.
## Hands off to the title screen.

const TITLE_SCENE: String = "res://scenes/main/title.tscn"


func _ready() -> void:
	# Deferred so the scene tree finishes building before the first transition.
	SceneRouter.go.call_deferred(TITLE_SCENE)
