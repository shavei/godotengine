class_name VillageMoment
extends Node2D
## A short moment in the village after the training tick (docs/GDD.md Sections 5.2 and
## 5.5): a villager reaching Adept or Master, or a newcomer moving in at a new Renown
## level. Bars frame the screen with a title, the camera goes to the villager, a ring
## bursts in the moment's color while `reveal` plays (the villager's new rank props, or
## the newcomer fading in), then the villager's line and what changed show in a box.
## About 4.5 seconds; Use, Accept or Back skip it once the burst has played. The village
## adds it to its world and points the camera at `focus`.

signal finished

const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.78, 0.72, 0.64)
const GOOD: Color = Color(0.6, 0.95, 0.55)
const OUTLINE: Color = Color(0.05, 0.03, 0.05)
const BAR_HEIGHT: float = 34.0
## The bars close in, then the ring bursts and the reveal plays over REVEAL_TIME.
const BURST_AT: float = 0.5
const REVEAL_TIME: float = 0.8
## The line and what changed appear.
const LINE_AT: float = 1.2
## It can be skipped once the burst has played, and ends on its own.
const SKIP_AT: float = 0.6
const DURATION: float = 4.5
const RING_TIME: float = 0.7
const RING_RADIUS: float = 40.0
const BURST_SHAKE: float = 0.2
## Where the dialogue box sits: near the bottom, or under the top bar for a villager
## low on the map (the camera cannot go past the map's edge to lift them above it).
const BOX_BOTTOM_Y: float = 238.0
const BOX_TOP_Y: float = 42.0

var villager: Villager
var color: Color = Color.WHITE
var elapsed: float = 0.0
var done: bool = false
## The camera follows this (it rests on the villager).
var focus: Node2D
## Called with 0 to 1 as the reveal plays (and 1 when the moment ends or is skipped).
var reveal: Callable

## Where the ring bursts: on the villager.
var _center: Vector2
var _burst: CPUParticles2D
var _burst_played: bool = false
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _dialogue: PanelContainer
var _hint: Label
var _title: Label


## Frames `who` with `title`; `line` is what they say, `detail` what changed. `box_on_top`
## moves the dialogue box up out of the villager's way.
func setup(who: Villager, tint: Color, title: String, line: String, detail: String,
		reveal_step: Callable = Callable(), box_on_top: bool = false) -> void:
	villager = who
	color = tint
	reveal = reveal_step
	focus = Node2D.new()
	focus.name = "Focus"
	add_child(focus)
	_center = villager.global_position + Vector2(0, -14)
	focus.global_position = _center
	_burst = CPUParticles2D.new()
	_burst.name = "Burst"
	_burst.amount = 36
	_burst.lifetime = 0.9
	_burst.one_shot = true
	_burst.explosiveness = 1.0
	_burst.local_coords = false
	_burst.emitting = false
	_burst.direction = Vector2.UP
	_burst.spread = 180.0
	_burst.initial_velocity_min = 50.0
	_burst.initial_velocity_max = 120.0
	_burst.gravity = Vector2(0, 90)
	_burst.damping_min = 40.0
	_burst.damping_max = 80.0
	_burst.scale_amount_min = 1.5
	_burst.scale_amount_max = 3.0
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, color.lightened(0.4))
	ramp.set_color(1, Color(color, 0.0))
	_burst.color_ramp = ramp
	add_child(_burst)
	_burst.global_position = _center
	_build_screen(title, line, detail)
	_dialogue.position.y = BOX_TOP_Y if box_on_top else BOX_BOTTOM_Y
	_update()


func _process(delta: float) -> void:
	step(delta)


## Moves the moment on by `delta` seconds (tests call it directly).
func step(delta: float) -> void:
	if done:
		return
	elapsed += delta
	_update()
	if elapsed >= DURATION:
		finish()


func _unhandled_input(event: InputEvent) -> void:
	if done:
		return
	for action: StringName in [&"interact", &"ui_accept", &"ui_cancel", &"pause"]:
		if event.is_action_pressed(action):
			get_viewport().set_input_as_handled()
			skip()
			return


func can_skip() -> bool:
	return elapsed >= SKIP_AT


## Ends the moment early once it may be skipped. Returns true if it ended.
func skip() -> bool:
	if not can_skip():
		return false
	finish()
	return true


## Leaves the reveal complete and ends the moment.
func finish() -> void:
	if done:
		return
	done = true
	if reveal.is_valid():
		reveal.call(1.0)
	finished.emit()
	queue_free()


## 0 before the burst, 1 once the reveal has played.
func reveal_amount() -> float:
	return clampf((elapsed - BURST_AT) / REVEAL_TIME, 0.0, 1.0)


func _update() -> void:
	if elapsed >= BURST_AT and not _burst_played:
		_burst_played = true
		_burst.restart()
		_burst.emitting = true
		EventBus.camera_shake_requested.emit(BURST_SHAKE)
	if reveal.is_valid():
		reveal.call(reveal_amount())
	var bars: float = _ease(clampf(elapsed / BURST_AT, 0.0, 1.0))
	if DURATION - elapsed < BURST_AT:
		bars = _ease(clampf((DURATION - elapsed) / BURST_AT, 0.0, 1.0))
	_top_bar.size.y = BAR_HEIGHT * bars
	_bottom_bar.size.y = BAR_HEIGHT * bars
	_bottom_bar.position.y = 360.0 - _bottom_bar.size.y
	_title.modulate.a = bars
	_dialogue.visible = elapsed >= LINE_AT
	_dialogue.modulate.a = clampf((elapsed - LINE_AT) / 0.3, 0.0, 1.0)
	_hint.visible = can_skip()
	_hint.text = "%s  Continue" % InputBindings.hint(&"interact")
	queue_redraw()


func _draw() -> void:
	var since: float = elapsed - BURST_AT
	if since >= 0.0 and since < RING_TIME:
		var t: float = since / RING_TIME
		var at: Vector2 = to_local(_center)
		draw_arc(at, RING_RADIUS * _ease(t), 0.0, TAU, 40, Color(color.lightened(0.3), 1.0 - t), 3.0 * (1.0 - t) + 1.0)
		draw_circle(at, 18.0 * (1.0 - t), Color(1, 1, 1, 0.45 * (1.0 - t)))


func _build_screen(title: String, line: String, detail: String) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Screen"
	layer.layer = 25
	add_child(layer)
	_top_bar = _bar("TopBar")
	layer.add_child(_top_bar)
	_bottom_bar = _bar("BottomBar")
	layer.add_child(_bottom_bar)
	_title = _label(title, 12, color.lightened(0.2), "Title")
	_title.position = Vector2(0, 8)
	_title.size = Vector2(640, 18)
	layer.add_child(_title)
	_dialogue = PanelContainer.new()
	_dialogue.name = "Dialogue"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.1, 0.08, 0.94)
	style.border_color = color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	_dialogue.add_theme_stylebox_override("panel", style)
	_dialogue.position = Vector2(110, BOX_BOTTOM_Y)
	_dialogue.size = Vector2(420, 0)
	_dialogue.custom_minimum_size = Vector2(420, 0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_dialogue.add_child(column)
	var data: VillagerData = villager.data
	var speaker: Label = _label(data.title() if data != null else "", 9, data.color.lightened(0.2) if data != null else INK, "Speaker")
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(speaker)
	column.add_child(_wrapped(line, 9, INK, "Line"))
	column.add_child(_wrapped(detail, 8, GOOD, "Detail"))
	layer.add_child(_dialogue)
	_hint = _label("", 8, DIM, "Hint")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.position = Vector2(0, 342)
	_hint.size = Vector2(630, 14)
	layer.add_child(_hint)


func _bar(node_name: String) -> ColorRect:
	var bar: ColorRect = ColorRect.new()
	bar.name = node_name
	bar.color = Color(0.03, 0.02, 0.03, 0.92)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.size = Vector2(640, 0)
	return bar


func _wrapped(text: String, font_size: int, tint: Color, node_name: String) -> Label:
	var label: Label = _label(text, font_size, tint, node_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(408, 0)
	label.visible = not text.is_empty()
	return label


func _label(text: String, font_size: int, tint: Color, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 3)
	return label


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
