@tool
class_name VillagePlot
extends Node2D
## A house plot (docs/GDD.md Section 5.4). Draws the house of the villager living here,
## in their color with their workplace on the sign; a gift trims the roof in the power's
## color (pillar 4). Training shows on the house too: an Adept flies a pennant in the
## power's color from the roof, a Master a second, gold one. An empty plot is a fenced
## patch of grass. The villager stands at the
## plot's origin, in front of the door. Placeholder art until M7.

const HOUSE_SIZE: Vector2 = Vector2(68, 40)
const ROOF_HEIGHT: float = 22.0
const OUTLINE: Color = Color(0.05, 0.03, 0.05)
## Gap between the house's front wall and the plot origin, where the villager stands.
const YARD: float = 44.0

## Plot index, matching VillagerState.plot.
@export var index: int = 0

var wall_color: Color = Color(0.55, 0.45, 0.35)
var workplace: String = ""
## The resident's power color, or transparent for none.
var power_color: Color = Color.TRANSPARENT
var occupied: bool = false
## The resident's rank (TrainingSystem), for the pennants.
var rank: int = TrainingSystem.NONE
## How far the newest pennant shows (0 to 1). A rank-up moment plays it from 0.
var rank_blend: float = 1.0:
	set(value):
		rank_blend = clampf(value, 0.0, 1.0)
		queue_redraw()
## How far the roof trim shows (0 to 1). The gift ceremony plays it from 0.
var trim_blend: float = 1.0:
	set(value):
		trim_blend = clampf(value, 0.0, 1.0)
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Houses block the hero like walls (world layer).
	var body: StaticBody2D = StaticBody2D.new()
	body.name = "House"
	body.collision_layer = PlaceholderRoom.WORLD_LAYER
	body.collision_mask = 0
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = HOUSE_SIZE
	var col: CollisionShape2D = CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -HOUSE_SIZE.y * 0.5 - YARD)
	body.add_child(col)
	add_child(body)


## Shows who lives here (null for an empty plot).
func set_resident(data: VillagerData, power: PowerData, rank_value: int = TrainingSystem.NONE) -> void:
	rank = rank_value
	occupied = data != null
	wall_color = data.color.lerp(Color(0.62, 0.52, 0.4), 0.55) if data != null else wall_color
	workplace = data.workplace if data != null else ""
	power_color = power.color if power != null else Color.TRANSPARENT
	queue_redraw()


func _draw() -> void:
	var base: Rect2 = Rect2(Vector2(-HOUSE_SIZE.x * 0.5, -HOUSE_SIZE.y - YARD), HOUSE_SIZE)
	if not occupied and not Engine.is_editor_hint():
		draw_rect(base.grow(4), Color(0.3, 0.36, 0.2))
		draw_rect(base.grow(4), Color(0.5, 0.4, 0.28), false, 2.0)
		_text("Empty plot", base.get_center() + Vector2(0, 3), Color(0.85, 0.8, 0.7))
		return
	draw_rect(base.grow(1), OUTLINE)
	draw_rect(base, wall_color)
	var roof: PackedVector2Array = [
		base.position + Vector2(-6, 0), base.position + Vector2(base.size.x + 6, 0),
		base.position + Vector2(base.size.x * 0.5, -ROOF_HEIGHT)]
	var roof_color: Color = Color(0.45, 0.24, 0.18)
	draw_colored_polygon(roof, roof_color)
	var outline: PackedVector2Array = PackedVector2Array([roof[0], roof[2], roof[1], roof[0]])
	draw_polyline(outline, roof_color.darkened(0.3), 1.0)
	if power_color.a > 0.0 and trim_blend > 0.0:
		draw_polyline(outline, Color(power_color, power_color.a * trim_blend), 1.0 + 2.0 * trim_blend)
	if power_color.a > 0.0 and rank >= TrainingSystem.ADEPT:
		var peak: Vector2 = roof[2]
		_pennant(peak, Vector2(1, 0), power_color, rank_blend if rank == TrainingSystem.ADEPT else 1.0)
		if rank >= TrainingSystem.MASTER:
			_pennant(peak, Vector2(-1, 0), Villager.GOLD, rank_blend)
	var door: Rect2 = Rect2(Vector2(-7, -YARD - 14), Vector2(14, 14))
	draw_rect(door, Color(0.3, 0.2, 0.14))
	if not workplace.is_empty():
		_text(workplace, base.position + Vector2(base.size.x * 0.5, 14), Color(0.98, 0.94, 0.84))


## A pole on the roof peak with a small flag pointing `side`, grown by `amount`.
func _pennant(peak: Vector2, side: Vector2, tint: Color, amount: float) -> void:
	if amount <= 0.0:
		return
	var foot: Vector2 = peak + side * 4.0
	var top: Vector2 = foot + Vector2(0, -16 * amount)
	draw_line(foot, top, Color(OUTLINE, amount), 1.5)
	var flag: PackedVector2Array = [top, top + side * 10.0 * amount + Vector2(0, 3), top + Vector2(0, 6 * amount)]
	draw_colored_polygon(flag, Color(tint, amount))


func _text(text: String, center: Vector2, color: Color) -> void:
	var font: Font = ThemeDB.fallback_font
	var at: Vector2 = center - Vector2(50, 0)
	draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 100, 8, 3, OUTLINE)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_CENTER, 100, 8, color)
