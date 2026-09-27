class_name RoomDoor
extends Area2D
## A doorway in a run room's top wall. The sign shows the room type behind it
## (docs/GDD.md Section 6.1). Locked doors are barred; walking into an open one
## emits `entered`.

signal entered(door: RoomDoor)

const HERO_BODY_LAYER: int = 2
const PICKUPS_LAYER: int = 8
const WIDTH: float = 28.0
const DEPTH: float = 26.0

## The map room behind the door, or -1 for stairs to the next floor.
var room_id: int = -1
var room_type: StringName = MapRoom.COMBAT
var caption: String = ""
var locked: bool = true:
	set(value):
		locked = value
		queue_redraw()
		if not locked:
			_check_overlap.call_deferred()

var _used: bool = false


static func create(target_room_id: int, type: StringName, text: String, is_locked: bool) -> RoomDoor:
	var door: RoomDoor = RoomDoor.new()
	door.room_id = target_room_id
	door.room_type = type
	door.caption = text
	door.locked = is_locked
	return door


func _ready() -> void:
	collision_layer = 1 << (PICKUPS_LAYER - 1)
	collision_mask = 1 << (HERO_BODY_LAYER - 1)
	monitorable = false
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(WIDTH - 4.0, 10.0)
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0.0, 5.0)
	add_child(col)
	body_entered.connect(_on_body_entered)


func _draw() -> void:
	var color: Color = MapRoom.type_color(room_type)
	var opening: Rect2 = Rect2(-WIDTH * 0.5, -DEPTH, WIDTH, DEPTH)
	draw_rect(opening.grow(3.0), color.darkened(0.35))
	draw_rect(opening, Color(0.04, 0.03, 0.05))
	if locked:
		for i: int in 4:
			var x: float = opening.position.x + 4.0 + i * (WIDTH - 8.0) / 3.0
			draw_line(Vector2(x, -DEPTH), Vector2(x, 0.0), Color(0.45, 0.4, 0.38), 2.0)
	var font: Font = ThemeDB.fallback_font
	var letter: String = MapRoom.type_letter(room_type) if room_id >= 0 else "v"
	draw_string(font, Vector2(-WIDTH * 0.5, -DEPTH * 0.5 + 6.0), letter, HORIZONTAL_ALIGNMENT_CENTER, WIDTH, 16, color)
	var alpha: float = 0.55 if locked else 1.0
	draw_string_outline(font, Vector2(-40.0, 20.0), caption, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 8, 3, Color(0.05, 0.03, 0.05, alpha))
	draw_string(font, Vector2(-40.0, 20.0), caption, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 8, Color(color, alpha))


func _on_body_entered(body: Node2D) -> void:
	if body is Hero and not locked and not _used:
		_used = true
		entered.emit(self)


func _check_overlap() -> void:
	if not is_inside_tree():
		return
	for body: Node2D in get_overlapping_bodies():
		_on_body_entered(body)
