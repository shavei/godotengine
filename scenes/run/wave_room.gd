extends Node2D
## M1 wave room: three waves of Mossy Hollow enemies, then a room clear.
## Interact (Shift / B) after the clear fights again. Esc (or Select) returns to the title.

const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const RESPAWN_DELAY: float = 1.5
const BANNER_TIME: float = 1.2

@onready var hero: Hero = $Actors/Hero
@onready var hud: Hud = $Hud
@onready var camera: GameCamera = $Camera
@onready var room: PlaceholderRoom = $Room
@onready var director: WaveDirector = $WaveDirector
@onready var wave_label: Label = %WaveLabel
@onready var banner: Label = %Banner


func _ready() -> void:
	hud.bind_hero(hero)
	var bounds: Rect2 = room.get_rect()
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	EventBus.hero_died.connect(_on_hero_died)
	director.wave_started.connect(_on_wave_started)
	director.room_cleared.connect(_on_room_cleared)
	# The director may have started before this script connected.
	if director.tracker != null and director.tracker.current_wave >= 0:
		_on_wave_started(director.tracker.current_wave, director.tracker.wave_count)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		SceneRouter.go(TITLE_SCENE)
	elif event.is_action_pressed(&"interact") and director.is_room_cleared():
		_restart()


func _on_wave_started(index: int, total: int) -> void:
	wave_label.text = "Wave %d / %d" % [index + 1, total]
	_show_banner("Wave %d" % (index + 1), BANNER_TIME)


func _on_room_cleared() -> void:
	wave_label.text = "Room clear"
	_show_banner("Room clear!\nShift / B to fight again", 0.0)


func _show_banner(text: String, duration: float) -> void:
	banner.text = text
	banner.show()
	banner.modulate.a = 1.0
	if duration > 0.0:
		var tween: Tween = create_tween()
		tween.tween_interval(duration)
		tween.tween_property(banner, "modulate:a", 0.0, 0.3)


func _on_hero_died(_player_id: int) -> void:
	%FellLabel.show()
	# A signal connection (not await) so nothing runs if the room is left first.
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_restart)


func _restart() -> void:
	SceneRouter.go(scene_file_path)
