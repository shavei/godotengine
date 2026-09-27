class_name SwingArc
extends Node2D
## Placeholder slash visual: an arc in front of the hero that fades out.

var color: Color = Color(1.0, 0.97, 0.85)

var _radius: float = 20.0
var _width: float = 4.0
var _duration: float = 0.1
var _time_left: float = 0.0


func play(radius: float, width: float, duration: float) -> void:
	_radius = radius
	_width = width
	_duration = maxf(duration, 0.01)
	_time_left = _duration
	queue_redraw()


func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left -= delta
		queue_redraw()


func _draw() -> void:
	if _time_left <= 0.0:
		return
	var alpha: float = _time_left / _duration
	draw_arc(Vector2.ZERO, _radius, -1.2, 1.2, 18, Color(color, alpha), _width)
	draw_arc(Vector2.ZERO, _radius - _width, -0.9, 0.9, 14, Color(color, alpha * 0.4), _width * 0.6)
