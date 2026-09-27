class_name RestSpot
extends Area2D
## One of a Rest room's offers (docs/GDD.md Section 6.2). Stand on it and press
## Interact to take it; the room then removes every offer.

signal chosen(spot: RestSpot, hero: Hero)

const HERO_BODY_LAYER: int = 2
const PICKUPS_LAYER: int = 8
const RADIUS: float = 18.0

var kind: StringName = &""
var caption: String = ""
var color: Color = Color.WHITE

var _hero: Hero = null
var _time: float = 0.0


static func create(offer_kind: StringName, text: String, tint: Color) -> RestSpot:
	var spot: RestSpot = RestSpot.new()
	spot.kind = offer_kind
	spot.caption = text
	spot.color = tint
	return spot


func _ready() -> void:
	collision_layer = 1 << (PICKUPS_LAYER - 1)
	collision_mask = 1 << (HERO_BODY_LAYER - 1)
	monitorable = false
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = RADIUS
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	body_entered.connect(func(body: Node2D) -> void:
		if body is Hero:
			_hero = body)
	body_exited.connect(func(body: Node2D) -> void:
		if body == _hero:
			_hero = null)


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if _hero != null and event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		chosen.emit(self, _hero)


func _draw() -> void:
	var glow: float = 0.5 + 0.5 * sin(_time * 3.0)
	draw_circle(Vector2.ZERO, RADIUS, Color(color, 0.18 + 0.12 * glow))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, color, 2.0)
	var font: Font = ThemeDB.fallback_font
	var text: String = caption + ("\nShift / B" if _hero != null else "")
	draw_multiline_string_outline(font, Vector2(-50.0, RADIUS + 12.0), text, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 8, -1, 3, Color(0.05, 0.03, 0.05))
	draw_multiline_string(font, Vector2(-50.0, RADIUS + 12.0), text, HORIZONTAL_ALIGNMENT_CENTER, 100.0, 8, -1, color)
