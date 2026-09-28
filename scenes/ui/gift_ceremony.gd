class_name GiftCeremony
extends Node2D
## The gift ceremony (docs/GDD.md Section 3.1, step 4), played in the village right after
## a gift. The screen frames the moment with bars, a Spark rises from the hero and flies
## to the villager, bursts in the power's color, the villager's clothes and their roof take
## that color, and the villager says their line with the service they now give. About
## 7 seconds (CeremonyTimeline). The first ceremony plays until its line has been read;
## later ones skip with Use, Accept or Back. The village adds it to its world (the Spark
## and particles live there) and points the camera at `focus`.

signal finished

const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.78, 0.72, 0.64)
const GOOD: Color = Color(0.6, 0.95, 0.55)
const OUTLINE: Color = Color(0.05, 0.03, 0.05)
const BAR_HEIGHT: float = 34.0
## How high the Spark rises above the hero, and how high its arc goes.
const RISE: float = 26.0
const ARC: float = 70.0
const SPARK_RADIUS: float = 6.0
const RING_TIME: float = 0.7
const RING_RADIUS: float = 44.0
const BURST_SHAKE: float = 0.35

var hero: Hero
var villager: Villager
var plot: VillagePlot
var power_color: Color = Color.WHITE
## Gift ceremonies seen before this one (the first cannot be skipped).
var ceremonies_seen: int = 0
var elapsed: float = 0.0
var done: bool = false
## The camera follows this: the hero first, then the Spark, then the villager.
var focus: Node2D

var _start: Vector2
var _end: Vector2
var _trail: CPUParticles2D
var _burst: CPUParticles2D
var _burst_played: bool = false
var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _dialogue: PanelContainer
var _hint: Label
var _title: Label


## Frames the gift of `power` to `who`. `title` names the moment, `line` is what the
## villager says, `service` what they do now.
func setup(by: Hero, who: Villager, house: VillagePlot, power: PowerData, title: String, line: String,
		service: String, seen: int) -> void:
	hero = by
	villager = who
	plot = house
	power_color = power.color if power != null else INK
	ceremonies_seen = seen
	_start = hero.global_position + Vector2(0, -14)
	_end = villager.global_position + Vector2(0, -14)
	villager.gift_blend = 0.0
	if plot != null:
		plot.trim_blend = 0.0
	focus = Node2D.new()
	focus.name = "Focus"
	add_child(focus)
	focus.global_position = hero.global_position
	_trail = _particles("Trail", false, 24, 0.5)
	_trail.emitting = false
	_burst = _particles("Burst", true, 48, 0.9)
	_burst.global_position = _end
	_build_screen(title, line, service)
	_update()


func _process(delta: float) -> void:
	step(delta)


## Moves the ceremony on by `delta` seconds (tests call it directly).
func step(delta: float) -> void:
	if done or villager == null:
		return
	elapsed += delta
	_update()
	if CeremonyTimeline.is_over(elapsed):
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
	return CeremonyTimeline.can_skip(ceremonies_seen, elapsed)


## Ends the ceremony early if it may be skipped. Returns true if it ended.
func skip() -> bool:
	if not can_skip():
		return false
	finish()
	return true


## Leaves the villager and their house in their new colors and ends the ceremony.
func finish() -> void:
	if done:
		return
	done = true
	villager.gift_blend = 1.0
	if plot != null:
		plot.trim_blend = 1.0
	finished.emit()
	queue_free()


## Where the Spark is now: rising above the hero, then arcing over to the villager.
func spark_position() -> Vector2:
	var top: Vector2 = _start + Vector2(0, -RISE)
	if elapsed < CeremonyTimeline.FLY_AT:
		var rise: float = clampf((elapsed - CeremonyTimeline.RISE_AT) / (CeremonyTimeline.FLY_AT - CeremonyTimeline.RISE_AT), 0.0, 1.0)
		return _start.lerp(top, _ease(rise))
	var t: float = _ease(CeremonyTimeline.flight(elapsed))
	var control: Vector2 = (top + _end) * 0.5 + Vector2(0, -ARC)
	return top.lerp(control, t).lerp(control.lerp(_end, t), t)


func _update() -> void:
	var flying: bool = elapsed >= CeremonyTimeline.RISE_AT and not CeremonyTimeline.has_burst(elapsed)
	_trail.emitting = flying
	if flying:
		_trail.global_position = spark_position()
		focus.global_position = spark_position()
	elif CeremonyTimeline.has_burst(elapsed):
		focus.global_position = _end
	if CeremonyTimeline.has_burst(elapsed) and not _burst_played:
		_burst_played = true
		_burst.restart()
		_burst.emitting = true
		EventBus.camera_shake_requested.emit(BURST_SHAKE)
	var swap: float = CeremonyTimeline.swap(elapsed)
	villager.gift_blend = swap
	if plot != null:
		plot.trim_blend = swap
	var bars: float = _ease(clampf(elapsed / CeremonyTimeline.RISE_AT, 0.0, 1.0))
	if CeremonyTimeline.DURATION - elapsed < CeremonyTimeline.RISE_AT:
		bars = _ease(clampf((CeremonyTimeline.DURATION - elapsed) / CeremonyTimeline.RISE_AT, 0.0, 1.0))
	_top_bar.size.y = BAR_HEIGHT * bars
	_bottom_bar.size.y = BAR_HEIGHT * bars
	_bottom_bar.position.y = 360.0 - _bottom_bar.size.y
	_title.modulate.a = bars
	_dialogue.visible = CeremonyTimeline.shows_line(elapsed)
	_dialogue.modulate.a = clampf((elapsed - CeremonyTimeline.LINE_AT) / 0.3, 0.0, 1.0)
	_hint.visible = can_skip()
	_hint.text = "%s  %s" % [InputBindings.hint(&"interact"), "Continue" if CeremonyTimeline.shows_line(elapsed) else "Skip"]
	queue_redraw()


func _draw() -> void:
	if elapsed >= CeremonyTimeline.RISE_AT and not CeremonyTimeline.has_burst(elapsed):
		var at: Vector2 = spark_position()
		var pulse: float = 0.5 + 0.5 * sin(elapsed * 14.0)
		draw_circle(at, SPARK_RADIUS * 2.2, Color(power_color, 0.18 + 0.1 * pulse))
		draw_circle(at, SPARK_RADIUS + 1.0, OUTLINE)
		draw_circle(at, SPARK_RADIUS, power_color.lightened(0.25))
		draw_circle(at, SPARK_RADIUS * 0.45, Color(1, 1, 1, 0.9))
	var since: float = elapsed - CeremonyTimeline.BURST_AT
	if since >= 0.0 and since < RING_TIME:
		var t: float = since / RING_TIME
		draw_arc(_end, RING_RADIUS * _ease(t), 0.0, TAU, 40, Color(power_color.lightened(0.3), 1.0 - t), 3.0 * (1.0 - t) + 1.0)
		draw_circle(_end, 20.0 * (1.0 - t), Color(1, 1, 1, 0.5 * (1.0 - t)))


func _particles(node_name: String, one_shot: bool, amount: int, lifetime: float) -> CPUParticles2D:
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.name = node_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.local_coords = false
	particles.emitting = false
	particles.explosiveness = 1.0 if one_shot else 0.0
	particles.direction = Vector2.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 60.0 if one_shot else 6.0
	particles.initial_velocity_max = 140.0 if one_shot else 20.0
	particles.gravity = Vector2(0, 90) if one_shot else Vector2(0, -10)
	particles.damping_min = 40.0 if one_shot else 0.0
	particles.damping_max = 80.0 if one_shot else 0.0
	particles.scale_amount_min = 1.5
	particles.scale_amount_max = 3.5 if one_shot else 2.5
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, power_color.lightened(0.4))
	ramp.set_color(1, Color(power_color, 0.0))
	particles.color_ramp = ramp
	add_child(particles)
	return particles


## Bars across the top and bottom, the title in the top bar, the line in a box at the bottom.
func _build_screen(title: String, line: String, service: String) -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "Screen"
	layer.layer = 25
	add_child(layer)
	_top_bar = _bar("TopBar")
	layer.add_child(_top_bar)
	_bottom_bar = _bar("BottomBar")
	layer.add_child(_bottom_bar)
	_title = _label(title, 12, power_color.lightened(0.2), "Title")
	_title.position = Vector2(0, 8)
	_title.size = Vector2(640, 18)
	layer.add_child(_title)
	_dialogue = PanelContainer.new()
	_dialogue.name = "Dialogue"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.1, 0.08, 0.94)
	style.border_color = power_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.set_content_margin_all(6)
	_dialogue.add_theme_stylebox_override("panel", style)
	_dialogue.position = Vector2(110, 238)
	_dialogue.size = Vector2(420, 0)
	_dialogue.custom_minimum_size = Vector2(420, 0)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	_dialogue.add_child(column)
	var speaker: Label = _label(villager.data.title() if villager.data != null else "", 9, villager.data.color.lightened(0.2) if villager.data != null else INK, "Speaker")
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(speaker)
	column.add_child(_wrapped(line, 9, INK, "Line"))
	column.add_child(_wrapped(service, 8, GOOD, "Service"))
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


func _wrapped(text: String, font_size: int, color: Color, node_name: String) -> Label:
	var label: Label = _label(text, font_size, color, node_name)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(408, 0)
	label.visible = not text.is_empty()
	return label


func _label(text: String, font_size: int, color: Color, node_name: String) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	label.add_theme_constant_override("outline_size", 3)
	return label


static func _ease(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)
