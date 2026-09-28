class_name StatusBadge
extends Node2D
## Shows an actor's statuses: a colored pip per status above it (one dot per stack),
## a stagger bar below it while the bar has any fill, and a tint on its visual
## (blue while chilled, pale while frozen). Placeholder art until M7.

const COLORS: Dictionary = {
	StatusEffects.BURN: Color(1.0, 0.55, 0.15),
	StatusEffects.CHILL: Color(0.55, 0.85, 1.0),
	StatusEffects.FREEZE: Color(0.85, 0.97, 1.0),
	StatusEffects.ROOT: Color(0.45, 0.85, 0.35),
	StatusEffects.STUN: Color(1.0, 0.9, 0.3),
}
const CHILL_TINT: Color = Color(0.7, 0.85, 1.0)
const FREEZE_TINT: Color = Color(0.6, 0.85, 1.3)
const PIP: float = 3.0
const BAR_SIZE: Vector2 = Vector2(16, 2)

var status: StatusComponent
## Tinted while chilled or frozen.
var target: CanvasItem
## Distance from the actor's center to the pips (above) and the bar (below).
var offset: float = 10.0


## Adds a badge to `owner_node` that follows `status_component`.
static func attach(owner_node: Node2D, status_component: StatusComponent, tint_target: CanvasItem, distance: float) -> StatusBadge:
	var badge: StatusBadge = StatusBadge.new()
	badge.status = status_component
	badge.target = tint_target
	badge.offset = distance
	badge.z_index = 4
	owner_node.add_child(badge)
	return badge


func _process(_delta: float) -> void:
	if target != null:
		if status.has(StatusEffects.FREEZE):
			target.modulate = FREEZE_TINT
		elif status.has(StatusEffects.CHILL):
			target.modulate = CHILL_TINT
		else:
			target.modulate = Color.WHITE
	queue_redraw()


func _draw() -> void:
	if status == null or status.effects == null:
		return
	var ids: Array[StringName] = status.effects.active_ids()
	var width: float = ids.size() * (PIP + 3.0) - 3.0
	var x: float = -width * 0.5
	for id: StringName in ids:
		var color: Color = COLORS.get(id, Color.WHITE)
		var center: Vector2 = Vector2(x + PIP * 0.5, -offset - PIP)
		draw_circle(center, PIP * 0.5 + 1.0, Color(0.05, 0.03, 0.05))
		draw_circle(center, PIP * 0.5, color)
		for s: int in range(1, status.stacks(id)):
			draw_rect(Rect2(center + Vector2(-0.5, -PIP - 1.0 - 2.0 * s), Vector2(1, 1)), color)
		x += PIP + 3.0
	var fill: float = status.effects.stagger_fraction()
	if fill > 0.0 or status.has(StatusEffects.STUN):
		var top_left: Vector2 = Vector2(-BAR_SIZE.x * 0.5, offset + 2.0)
		draw_rect(Rect2(top_left - Vector2.ONE, BAR_SIZE + Vector2(2, 2)), Color(0.05, 0.03, 0.05, 0.8))
		var shown: float = 1.0 if status.has(StatusEffects.STUN) else fill
		draw_rect(Rect2(top_left, Vector2(BAR_SIZE.x * shown, BAR_SIZE.y)), COLORS[StatusEffects.STUN])
