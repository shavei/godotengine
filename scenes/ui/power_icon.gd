class_name PowerIcon
extends RefCounted
## Placeholder power icons until M7 (docs/CONTENT.md Section 1: color and icon shape).
## draw() paints a PowerData's shape in its color onto any CanvasItem.


## Draws `shape` centered at `center`, about `size` px across.
static func draw(canvas: CanvasItem, shape: StringName, center: Vector2, size: float, color: Color) -> void:
	var r: float = size * 0.5
	var dark: Color = Color(0.05, 0.03, 0.05)
	match shape:
		&"flame":
			var flame: PackedVector2Array = [
				Vector2(0, -r), Vector2(r * 0.45, -r * 0.2), Vector2(r * 0.7, r * 0.35), Vector2(r * 0.4, r),
				Vector2(-r * 0.4, r), Vector2(-r * 0.7, r * 0.35), Vector2(-r * 0.2, -r * 0.1)]
			_polygon(canvas, flame, center, color, dark)
			canvas.draw_circle(center + Vector2(0, r * 0.45), r * 0.3, color.lightened(0.5))
		&"snowflake":
			for i: int in 3:
				var arm: Vector2 = Vector2.UP.rotated(PI / 3.0 * i) * r
				canvas.draw_line(center - arm, center + arm, dark, 4.0)
			for i: int in 3:
				var arm: Vector2 = Vector2.UP.rotated(PI / 3.0 * i) * r
				canvas.draw_line(center - arm, center + arm, color, 2.0)
		&"square":
			var half: Vector2 = Vector2.ONE * r * 0.8
			canvas.draw_rect(Rect2(center - half - Vector2.ONE, half * 2.0 + Vector2(2, 2)), dark)
			canvas.draw_rect(Rect2(center - half, half * 2.0), color)
			canvas.draw_rect(Rect2(center - half * 0.4, half * 0.8), color.darkened(0.25))
		&"leaf":
			var leaf: PackedVector2Array = [
				Vector2(0, -r), Vector2(r * 0.6, -r * 0.3), Vector2(r * 0.5, r * 0.5), Vector2(0, r),
				Vector2(-r * 0.5, r * 0.5), Vector2(-r * 0.6, -r * 0.3)]
			_polygon(canvas, leaf, center, color, dark)
			canvas.draw_line(center + Vector2(0, -r * 0.7), center + Vector2(0, r), dark, 1.0)
		_:
			canvas.draw_circle(center, r * 0.8 + 1.0, dark)
			canvas.draw_circle(center, r * 0.8, color)


static func _polygon(canvas: CanvasItem, points: PackedVector2Array, center: Vector2, color: Color, outline: Color) -> void:
	var moved: PackedVector2Array = []
	for point: Vector2 in points:
		moved.append(center + point)
	canvas.draw_colored_polygon(moved, color)
	moved.append(moved[0])
	canvas.draw_polyline(moved, outline, 1.0)
