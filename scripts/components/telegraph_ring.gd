class_name TelegraphRing
extends Node2D
## Attack warning (docs/GDD.md Section 7.4): an outline shows the danger zone and a
## filled disc grows until the hit lands. Enemies reuse this for area attacks.

@export var color: Color = Color(1.0, 0.3, 0.2)

var _radius: float = 32.0
var _duration: float = 0.6
var _time: float = 0.0
var _playing: bool = false


func play(radius: float, duration: float) -> void:
	_radius = radius
	_duration = maxf(duration, 0.01)
	_time = 0.0
	_playing = true
	queue_redraw()


func stop() -> void:
	_playing = false
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
	draw_circle(Vector2.ZERO, _radius * t, Color(color, 0.25 + 0.25 * t))
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 40, Color(color, 0.8), 1.5)
