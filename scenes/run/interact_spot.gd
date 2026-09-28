class_name InteractSpot
extends Area2D
## Something the hero stands on and takes with Interact: a Rest room comfort, a treasure
## chest, a Merchant's ware, an Event choice, a power orb, or in the village the Shrine,
## the gate and each villager. The scene decides what happens. A disabled spot (the hero
## cannot pay) reports `refused`.

signal chosen(spot: InteractSpot, hero: Hero)
signal refused(spot: InteractSpot, hero: Hero)

const HERO_BODY_LAYER: int = 2
const PICKUPS_LAYER: int = 8
const RADIUS: float = 18.0
const TEXT_WIDTH: float = 110.0

var kind: StringName = &""
var caption: String = ""
var color: Color = Color.WHITE
## Room data for this spot (a ware's price, an Event choice, a power orb's power id).
var payload: Variant = null
## A PowerIcon shape drawn in the middle (power orbs), or &"" for none.
var icon_shape: StringName = &""
## False: draw nothing but the caption, and only while the hero stands here (a villager
## draws its own body).
var show_ring: bool = true
var enabled: bool = true:
	set(value):
		enabled = value
		queue_redraw()

var _hero: Hero = null
var _time: float = 0.0


static func create(spot_kind: StringName, text: String, tint: Color, data: Variant = null) -> InteractSpot:
	var spot: InteractSpot = InteractSpot.new()
	spot.kind = spot_kind
	spot.caption = text
	spot.color = tint
	spot.payload = data
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
		if enabled:
			chosen.emit(self, _hero)
		else:
			refused.emit(self, _hero)


func _draw() -> void:
	var tint: Color = color if enabled else Color(color.darkened(0.4), 0.7)
	var glow: float = 0.5 + 0.5 * sin(_time * 3.0) if enabled else 0.0
	if not show_ring and _hero == null:
		return
	if show_ring:
		_draw_ring(tint, glow)
	var font: Font = ThemeDB.fallback_font
	var text: String = caption + ("\n" + InputBindings.hint(&"interact") if _hero != null else "")
	var at: Vector2 = Vector2(-TEXT_WIDTH * 0.5, RADIUS + 12.0)
	draw_multiline_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, 8, -1, 3, Color(0.05, 0.03, 0.05))
	draw_multiline_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, TEXT_WIDTH, 8, -1, tint)


## True while a hero stands on the spot.
func is_occupied() -> bool:
	return _hero != null


func _draw_ring(tint: Color, glow: float) -> void:
	draw_circle(Vector2.ZERO, RADIUS, Color(tint, 0.18 + 0.12 * glow))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 32, tint, 2.0)
	if icon_shape != &"":
		PowerIcon.draw(self, icon_shape, Vector2(0, -2.0 * glow), RADIUS * 1.1, tint)
