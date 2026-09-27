class_name TelegraphRing
extends Node2D
## Attack warning (docs/GDD.md Section 7.4): an outline shows the danger zone and a
## fill grows until the hit lands. play() warns of an area, play_line() of a charge
## or shot lane along `direction`.

const DANGER_COLOR: Color = Color(1.0, 0.3, 0.2)
## A lobbed cloud's landing spot (Spore Witch).
const SPORE_COLOR: Color = Color(0.75, 0.9, 0.35)

@export var color: Color = DANGER_COLOR

enum Mode { CIRCLE, LINE }

var _mode: Mode = Mode.CIRCLE
var _radius: float = 32.0
var _direction: Vector2 = Vector2.RIGHT
var _length: float = 100.0
var _duration: float = 0.6
var _time: float = 0.0
var _playing: bool = false


func play(radius: float, duration: float) -> void:
	_mode = Mode.CIRCLE
	_radius = radius
	_start(duration)


## `width` is the lane's full width.
func play_line(direction: Vector2, length: float, width: float, duration: float) -> void:
	_mode = Mode.LINE
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	_length = length
	_radius = width * 0.5
	_start(duration)


func stop() -> void:
	_playing = false
	queue_redraw()


func is_playing() -> bool:
	return _playing


func _start(duration: float) -> void:
	_duration = maxf(duration, 0.01)
	_time = 0.0
	_playing = true
	queue_redraw()


func _process(delta: float) -> void:
	if not _playing:
		return
	_time += delta
	if _time >= _duration:
		_playing = false
	queue_redraw()


func _draw() -> void:
	if not _playing:
		return
	var t: float = clampf(_time / _duration, 0.0, 1.0)
	if _mode == Mode.CIRCLE:
		draw_circle(Vector2.ZERO, _radius * t, Color(color, 0.25 + 0.25 * t))
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 40, Color(color, 0.8), 1.5)
		return
	draw_set_transform(Vector2.ZERO, _direction.angle())
	draw_rect(Rect2(0.0, -_radius, _length * t, _radius * 2.0), Color(color, 0.25 + 0.25 * t))
	draw_rect(Rect2(0.0, -_radius, _length, _radius * 2.0), Color(color, 0.8), false, 1.0)
	draw_set_transform(Vector2.ZERO)
