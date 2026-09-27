@tool
class_name PlaceholderShape
extends Node2D
## Placeholder art until M7: a filled circle or rectangle with an outline and an optional
## facing notch. Works with the hit flash shader because it draws on its own canvas item.

enum Shape { CIRCLE, RECT }

@export var shape: Shape = Shape.CIRCLE:
	set(value):
		shape = value
		queue_redraw()
@export var size: Vector2 = Vector2(16, 16):
	set(value):
		size = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
@export var outline_color: Color = Color(0.05, 0.03, 0.05):
	set(value):
		outline_color = value
		queue_redraw()
## Draws a small notch pointing along +x (rotate the node to show facing).
@export var show_notch: bool = false:
	set(value):
		show_notch = value
		queue_redraw()


func _draw() -> void:
	var half: Vector2 = size * 0.5
	if shape == Shape.CIRCLE:
		draw_circle(Vector2.ZERO, half.x + 1.0, outline_color)
		draw_circle(Vector2.ZERO, half.x, color)
	else:
		draw_rect(Rect2(-half - Vector2.ONE, size + Vector2(2, 2)), outline_color)
		draw_rect(Rect2(-half, size), color)
	if show_notch:
		var tip: Vector2 = Vector2(half.x + 4.0, 0)
		draw_colored_polygon(PackedVector2Array([tip, Vector2(half.x - 2.0, -3), Vector2(half.x - 2.0, 3)]), outline_color)
