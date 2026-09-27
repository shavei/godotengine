class_name DamageNumber
extends Label
## Floating damage text. Spawn with DamageNumber.spawn(); it frees itself.

const RISE: float = 18.0
const LIFETIME: float = 0.6
const COLOR_NORMAL: Color = Color(1.0, 0.95, 0.85)
const COLOR_CRIT: Color = Color(1.0, 0.8, 0.2)
const COLOR_HERO: Color = Color(1.0, 0.4, 0.35)
const COLOR_HEAL: Color = Color(0.5, 1.0, 0.55)


## `parent` is usually the current room so numbers do not move with the actor.
static func spawn(parent: Node, world_pos: Vector2, value: String, color: Color, big: bool = false) -> DamageNumber:
	var label: DamageNumber = DamageNumber.new()
	label.text = value
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.05))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 12 if big else 9)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size = Vector2(40, 14)
	label.z_index = 50
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	label.global_position = world_pos + Vector2(-20 + randf_range(-4.0, 4.0), -24)
	return label


func _ready() -> void:
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(self, "position:y", position.y - RISE, LIFETIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.5).set_delay(LIFETIME * 0.5)
	tween.chain().tween_callback(queue_free)
