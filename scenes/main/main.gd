extends Node
## Boot scene. Autoloads (ContentDB, SaveManager, ...) are ready before this runs.
## Loads the player's controls and the profile, then hands off to the title screen.

const TITLE_SCENE: String = "res://scenes/main/title.tscn"


func _ready() -> void:
	# The player's remapped controls (Controls menu) replace the defaults.
	InputBindings.load_saved()
	GameState.load_profile()
	# Deferred so the scene tree finishes building before the first transition.
	SceneRouter.go.call_deferred(TITLE_SCENE)
