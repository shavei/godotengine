extends Node2D
## Tuning room: a safe place to tune combat feel with a controller.
## Start (or Esc) opens the tuning menu, which pauses the game. The menu can spawn a
## round of Mossy Hollow enemies, save the results, or go back to the title.

const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const RESPAWN_DELAY: float = 1.5

@onready var hero: Hero = $Actors/Hero
@onready var hud: Hud = $Hud
@onready var camera: GameCamera = $Camera
@onready var room: PlaceholderRoom = $Room
@onready var director: WaveDirector = $WaveDirector
@onready var wave_label: Label = %WaveLabel


func _ready() -> void:
	hud.bind_hero(hero)
	$Overlay/Help.text = "Tuning menu %s    Attack %s    Dodge %s    Flask %s    Aim right stick" % [
		InputBindings.hint(&"pause"), InputBindings.hint(&"attack"), InputBindings.hint(&"dodge"), InputBindings.hint(&"flask")]
	var bounds: Rect2 = room.get_rect()
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	EventBus.hero_died.connect(_on_hero_died)
	director.wave_started.connect(_on_wave_started)
	director.room_cleared.connect(_on_room_cleared)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		open_menu()


func open_menu() -> void:
	var actions: Array[Array] = [
		["Spawn enemies", spawn_enemies],
		["Back to title", _go_to_title],
	]
	TuningPanel.open(actions)


## Starts the Mossy Hollow test waves, unless enemies are already out.
func spawn_enemies() -> void:
	if director.tracker != null and not director.is_room_cleared():
		TuningPanel.status_text = "Enemies are already out."
		return
	TuningPanel.close()
	director.start()


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
