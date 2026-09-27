@tool
class_name PlaceholderRoom
extends Node2D
## Placeholder arena until tilesets arrive (M2, M7): a checkered floor, a wall ring
## and optional pillars, all with collision on the `world` layer.

const WORLD_LAYER: int = 1

@export var size_tiles: Vector2i = Vector2i(24, 15):
	set(value):
		size_tiles = value
		queue_redraw()
@export var tile_size: int = 32:
	set(value):
		tile_size = value
		queue_redraw()
## Solid tiles inside the room, in tile coordinates.
@export var pillars: Array[Vector2i] = []:
	set(value):
		pillars = value
		queue_redraw()
@export var floor_a: Color = Color(0.2, 0.26, 0.19)
@export var floor_b: Color = Color(0.18, 0.24, 0.17)
@export var wall_color: Color = Color(0.3, 0.24, 0.2)
@export var wall_top_color: Color = Color(0.42, 0.34, 0.27)


func _ready() -> void:
	if not Engine.is_editor_hint():
		_build_collision()


## Swaps the pillars at runtime (a run room picks its layout after loading).
func set_pillars(cells: Array[Vector2i]) -> void:
	pillars = cells
	var old: Node = get_node_or_null(^"Walls")
	if old != null:
		remove_child(old)
		old.queue_free()
	_build_collision()


## True for walls and pillars.
func is_solid(cell: Vector2i) -> bool:
	return _is_solid(cell)


## Room bounds in local pixels, walls included.
func get_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(size_tiles * tile_size))


## Walkable area in local pixels (inside the walls).
func get_inner_rect() -> Rect2:
	return get_rect().grow(-tile_size)


func _draw() -> void:
	for y: int in size_tiles.y:
		for x: int in size_tiles.x:
			var cell: Vector2i = Vector2i(x, y)
			var rect: Rect2 = Rect2(Vector2(cell * tile_size), Vector2(tile_size, tile_size))
			if _is_solid(cell):
				draw_rect(rect, wall_color)
				draw_rect(Rect2(rect.position, Vector2(tile_size, 6)), wall_top_color)
			else:
				draw_rect(rect, floor_a if (x + y) % 2 == 0 else floor_b)


func _is_solid(cell: Vector2i) -> bool:
	var edge: bool = cell.x == 0 or cell.y == 0 or cell.x == size_tiles.x - 1 or cell.y == size_tiles.y - 1
	return edge or pillars.has(cell)


func _build_collision() -> void:
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "Walls"
	body.collision_layer = WORLD_LAYER
	body.collision_mask = 0
	add_child(body)
	var full: Vector2 = Vector2(size_tiles * tile_size)
	var t: float = tile_size
	_add_box(body, Rect2(0, 0, full.x, t))
	_add_box(body, Rect2(0, full.y - t, full.x, t))
	_add_box(body, Rect2(0, 0, t, full.y))
	_add_box(body, Rect2(full.x - t, 0, t, full.y))
	for cell: Vector2i in pillars:
		_add_box(body, Rect2(Vector2(cell * tile_size), Vector2(t, t)))


func _add_box(body: StaticBody2D, rect: Rect2) -> void:
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = rect.size
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = rect.get_center()
	body.add_child(col)
