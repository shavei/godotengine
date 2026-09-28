class_name Villager
extends Node2D
## A villager standing in front of their house (docs/GDD.md Section 5.1). Placeholder
## body until sprites (M7): their job color and their name at their feet. Once they hold
## a power their clothes take on its color (a palette swap and a sash), with a glow, its
## icon beside their head and their rank (pillar 4: see your choices). Stand next to them and press Interact to talk (`talked_to`).

signal talked_to(villager: Villager, hero: Hero)

const BODY_RADIUS: float = 8.0
const HEAD_RADIUS: float = 5.0
const SKIN: Color = Color(0.93, 0.8, 0.66)
const OUTLINE: Color = Color(0.05, 0.03, 0.05)
## How far a gift shifts the villager's clothes toward the power's color.
const PALETTE_SHIFT: float = 0.5

var data: VillagerData
var state: VillagerState
## The power they hold, or null.
var power: PowerData
var rank: int = TrainingSystem.NONE
## How far the villager wears their power's colors (0 to 1). The gift ceremony plays it
## from 0; otherwise it is always 1.
var gift_blend: float = 1.0:
	set(value):
		gift_blend = clampf(value, 0.0, 1.0)
		queue_redraw()

var _time: float = 0.0

@onready var spot: InteractSpot = $Spot


func _ready() -> void:
	spot.kind = &"villager"
	spot.show_ring = false
	spot.color = Color(0.95, 0.9, 0.78)
	spot.chosen.connect(func(_spot: InteractSpot, hero: Hero) -> void: talked_to.emit(self, hero))
	_update_caption()


## Shows this villager (their data and saved state).
func setup(villager_data: VillagerData, villager_state: VillagerState, balance: BalanceData) -> void:
	data = villager_data
	state = villager_state
	power = ContentDB.get_item(&"powers", state.power_id) as PowerData if state.has_power() else null
	rank = TrainingSystem.rank(state, balance)
	name = "Villager%s" % String(state.villager_id).capitalize()
	_update_caption()
	queue_redraw()


func _process(delta: float) -> void:
	if power != null:
		_time += delta
		queue_redraw()


func _update_caption() -> void:
	if spot != null and data != null:
		spot.caption = "Talk to %s" % data.display_name


func _draw() -> void:
	if data == null:
		return
	var blend: float = gift_blend if power != null else 0.0
	if blend > 0.0:
		var pulse: float = 0.5 + 0.5 * sin(_time * 2.5)
		draw_circle(Vector2(0, -12), 18.0, Color(power.color, (0.14 + 0.1 * pulse) * blend))
		draw_arc(Vector2(0, -12), 18.0, 0.0, TAU, 32, Color(power.color, 0.6 * blend), 1.5)
	var body: Vector2 = Vector2(0, -BODY_RADIUS)
	draw_circle(body, BODY_RADIUS + 1.0, OUTLINE)
	draw_circle(body, BODY_RADIUS, body_color())
	if blend > 0.0:
		# A sash across the body in the power's color.
		draw_line(body + Vector2(-5, -5), body + Vector2(5, 5), Color(power.color.lightened(0.2), blend), 3.0)
	draw_circle(Vector2(0, -BODY_RADIUS * 2 - HEAD_RADIUS + 2), HEAD_RADIUS + 1.0, OUTLINE)
	draw_circle(Vector2(0, -BODY_RADIUS * 2 - HEAD_RADIUS + 2), HEAD_RADIUS, SKIN)
	var font: Font = ThemeDB.fallback_font
	var label: String = data.display_name
	var label_color: Color = Color(0.95, 0.9, 0.78)
	if blend > 0.0:
		PowerIcon.draw(self, power.icon_shape, Vector2(15, -26), 11.0, Color(power.color, blend))
	if blend >= 1.0:
		label = "%s  %s" % [data.display_name, TrainingSystem.rank_name(rank)]
		label_color = power.color
	var at: Vector2 = Vector2(-60, 16)
	draw_string_outline(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, 3, OUTLINE)
	draw_string(font, at, label, HORIZONTAL_ALIGNMENT_CENTER, 120, 8, label_color)


## Their clothes: the job color, shifted toward the power's color once they hold one.
func body_color() -> Color:
	if power == null:
		return data.color
	return data.color.lerp(power.color, PALETTE_SHIFT * gift_blend)
