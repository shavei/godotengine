class_name PowerSlotView
extends Control
## One power slot on the HUD: the power's icon, a dark cover that shrinks as the
## cooldown runs out (with the seconds left), the level, and the button to press.
## An empty slot shows a dim frame.

const SIZE: float = 24.0
const FRAME: Color = Color(0.08, 0.06, 0.08, 0.85)
const EDGE: Color = Color(0.02, 0.01, 0.02)
const COVER: Color = Color(0.0, 0.0, 0.0, 0.6)
const DENIED: Color = Color(1.0, 0.3, 0.3)
const READY_FLASH: float = 0.25

var loadout: PowerLoadout
var index: int = 0
var action: StringName = &""

var _was_ready: bool = true
var _flash: float = 0.0
var _denied: float = 0.0
var _font: Font


func _init(source: PowerLoadout = null, slot_index: int = 0, input_action: StringName = &"") -> void:
	loadout = source
	index = slot_index
	action = input_action
	custom_minimum_size = Vector2(SIZE, SIZE + 10.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_font = get_theme_default_font()


## Blinks the frame red (pressed while cooling down or empty).
func deny() -> void:
	_denied = 0.3


func _process(delta: float) -> void:
	var ready_now: bool = loadout != null and loadout.is_ready(index)
	if ready_now and not _was_ready:
		_flash = READY_FLASH
	_was_ready = ready_now
	_flash = maxf(_flash - delta, 0.0)
	_denied = maxf(_denied - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var box: Rect2 = Rect2(Vector2.ZERO, Vector2(SIZE, SIZE))
	var slot: PowerLoadout.Slot = loadout.slot(index) if loadout != null else null
	var edge: Color = DENIED if _denied > 0.0 else EDGE
	draw_rect(box.grow(1.0), edge)
	draw_rect(box, FRAME)
	if slot == null:
		draw_rect(box.grow(-3.0), Color(1, 1, 1, 0.08), false, 1.0)
	else:
		PowerIcon.draw(self, slot.power.icon_shape, box.get_center(), SIZE - 8.0, slot.power.color)
		var fraction: float = loadout.cooldown_fraction(index)
		if fraction > 0.0:
			draw_rect(Rect2(0, SIZE * (1.0 - fraction), SIZE, SIZE * fraction), COVER)
			_text(str(ceili(slot.remaining)), box.get_center() + Vector2(0, 3), 9, Color.WHITE)
		if _flash > 0.0:
			draw_rect(box, Color(1, 1, 1, _flash / READY_FLASH * 0.5))
		_text(str(slot.level), Vector2(SIZE - 3.0, 7.0), 6, Color(1, 0.95, 0.7))
	_text(InputBindings.hint_for(action, InputBindings.active_kind), Vector2(SIZE * 0.5, SIZE + 8.0), 7, Color(1, 1, 1, 0.7))


func _text(value: String, center: Vector2, font_size: int, color: Color) -> void:
	if _font == null:
		return
	var width: float = _font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var at: Vector2 = Vector2(center.x - width * 0.5, center.y)
	draw_string_outline(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, EDGE)
	draw_string(_font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
