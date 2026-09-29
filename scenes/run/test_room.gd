extends Node2D
## M1 combat sandbox: the hero, training dummies and a sparring dummy that slams back.
## Enemies and waves join in the next M1 step. Esc (or Select) returns to the title.

const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const RESPAWN_DELAY: float = 1.5

@onready var hero: Hero = $Actors/Hero
@onready var hud: Hud = $Hud
@onready var camera: GameCamera = $Camera
@onready var room: PlaceholderRoom = $Room


func _ready() -> void:
	hud.bind_hero(hero)
	CombatHelp.attach($Overlay/Help, [["Title", &"pause"]])
	var bounds: Rect2 = room.get_rect()
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	EventBus.hero_died.connect(_on_hero_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		SceneRouter.go(TITLE_SCENE)


func _on_hero_died(_player_id: int) -> void:
	%FellLabel.show()
	# A signal connection (not await) so nothing runs if the room is left first.
	get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_restart)


func _restart() -> void:
	SceneRouter.go(scene_file_path)
