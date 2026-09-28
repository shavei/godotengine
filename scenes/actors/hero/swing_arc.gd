class_name SwingArc
extends Node2D
## Placeholder slash visual: an arc in front of the hero that sweeps from one side to the
## other, then fades out. Combo steps sweep opposite ways; the finisher is wider and gold.

const SWEEP_SHARE: float = 0.6
const FINISHER_COLOR: Color = Color(1.0, 0.8, 0.4)

var color: Color = Color(1.0, 0.97, 0.85)

var _radius: float = 20.0
var _width: float = 4.0
var _duration: float = 0.1
var _time_left: float = 0.0
var _sweep: float = 1.0
var _arc: float = 1.2
var _tint: Color = Color.WHITE
var _finisher: bool = false


func play(radius: float, width: float, duration: float, sweep: float = 1.0, arc: float = 1.2, finisher: bool = false) -> void:
	_radius = radius
	_width = width
	_duration = maxf(duration, 0.01)
	_time_left = _duration
	_sweep = sweep
	_arc = arc
	_finisher = finisher
	_tint = FINISHER_COLOR if finisher else color
	queue_redraw()


## The part of the arc drawn so far, as [from, to] angles. It grows over the first
## SWEEP_SHARE of the slash; a sweep of 0 shows the whole arc at once.
func drawn_span() -> Vector2:
	var progress: float = 1.0 if is_zero_approx(_sweep) else clampf((1.0 - _time_left / _duration) / SWEEP_SHARE, 0.0, 1.0)
	var start: float = -_arc * signf(_sweep) if not is_zero_approx(_sweep) else -_arc
	var end: float = start + 2.0 * _arc * progress * (signf(_sweep) if not is_zero_approx(_sweep) else 1.0)
	return Vector2(minf(start, end), maxf(start, end))


func is_playing() -> bool:
	return _time_left > 0.0


func _process(delta: float) -> void:
	if _time_left > 0.0:
		_time_left -= delta
		queue_redraw()


func _draw() -> void:
	if _time_left <= 0.0:
		return
	var fade: float = clampf(_time_left / (_duration * (1.0 - SWEEP_SHARE)), 0.0, 1.0)
	var span: Vector2 = drawn_span()
	if span.y - span.x < 0.05:
		return
	draw_arc(Vector2.ZERO, _radius, span.x, span.y, 20, Color(_tint, fade), _width)
	draw_arc(Vector2.ZERO, _radius - _width, span.x * 0.8, span.y * 0.8, 16, Color(_tint, fade * 0.4), _width * 0.6)
	if _finisher:
		draw_arc(Vector2.ZERO, _radius + _width, span.x, span.y, 20, Color(_tint, fade * 0.35), _width * 0.5)
	if not is_zero_approx(_sweep) and fade >= 1.0:
		# The leading edge: a bright head where the blade is now.
		var head: float = span.y if _sweep > 0.0 else span.x
		draw_circle(Vector2.from_angle(head) * _radius, _width * 0.7, Color(1, 1, 1, 0.9))
