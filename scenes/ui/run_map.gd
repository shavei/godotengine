class_name RunMap
extends CanvasLayer
## The floor map (docs/GDD.md Section 13, Run map): rooms bottom to top, the path taken,
## where you are and which rooms you can reach next. Map (Tab / Back) toggles it.

const PANEL_RECT: Rect2 = Rect2(464.0, 30.0, 170.0, 300.0)
const ROOM_RADIUS: float = 7.0
const MARGIN: Vector2 = Vector2(14.0, 28.0)
const LEGEND: String = "F Fight   E Elite   T Treasure\nR Rest   M Merchant   ? Event   B Boss"
const INK: Color = Color(0.95, 0.9, 0.78)
const OUTLINE: Color = Color(0.05, 0.03, 0.05)

var run: RunState

var _panel: Panel
var _view: Control
var _time: float = 0.0


func _ready() -> void:
	layer = 15
	_panel = Panel.new()
	_panel.position = PANEL_RECT.position
	_panel.size = PANEL_RECT.size
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.06, 0.08, 0.88)
	style.border_color = Color(0.45, 0.38, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	_panel.add_theme_stylebox_override(&"panel", style)
	add_child(_panel)
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_map)
	_panel.add_child(_view)
	visible = false


func show_run(run_state: RunState, open: bool) -> void:
	run = run_state
	visible = open
	_view.queue_redraw()


func is_open() -> bool:
	return visible


func toggle() -> void:
	visible = not visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"map"):
		get_viewport().set_input_as_handled()
		toggle()


func _process(delta: float) -> void:
	if visible:
		_time += delta
		_view.queue_redraw()


## Where a room sits in the panel. Row -1 is the corridor start at the bottom.
func room_position(row: int, lane: int, row_width: int) -> Vector2:
	var area: Rect2 = Rect2(MARGIN, PANEL_RECT.size - MARGIN * Vector2(2.0, 1.0) - Vector2(0.0, 30.0))
	var slots: int = run.map.row_count() + 1
	var step: float = area.size.y / maxf(1.0, slots - 1)
	var x: float = area.position.x + area.size.x * (lane + 0.5) / row_width
	return Vector2(x, area.end.y - (row + 1) * step)


func _draw_map() -> void:
	if run == null or run.map == null:
		return
	var font: Font = ThemeDB.fallback_font
	var title: String = "%s   Floor %d / %d" % [run.region.display_name, run.floor_index + 1, run.region.floor_count]
	_view.draw_string(font, Vector2(0.0, 14.0), title, HORIZONTAL_ALIGNMENT_CENTER, PANEL_RECT.size.x, 9, INK)
	var map: FloorMap = run.map
	var start: Vector2 = room_position(-1, 0, 1)
	var choices: Array[int] = run.next_choices()
	var pulse: float = 0.5 + 0.5 * sin(_time * 5.0)
	# Paths first so rooms draw on top.
	for room: MapRoom in map.get_row(0):
		var walked: bool = not run.path.is_empty() and run.path[0] == room.id
		_draw_link(start, _pos(room), walked)
	for room: MapRoom in map.rooms:
		var index: int = run.path.find(room.id)
		for next_id: int in room.next:
			var walked: bool = index >= 0 and index + 1 < run.path.size() and run.path[index + 1] == next_id
			_draw_link(_pos(room), _pos(map.get_room(next_id)), walked)
	_view.draw_circle(start, 4.0, INK if run.is_in_corridor() else Color(INK, 0.5))
	for room: MapRoom in map.rooms:
		var at: Vector2 = _pos(room)
		var color: Color = MapRoom.type_color(room.type)
		var radius: float = ROOM_RADIUS + (2.0 if room.row == map.depth() else 0.0)
		var visited: bool = run.path.has(room.id)
		var reachable: bool = choices.has(room.id)
		_view.draw_circle(at, radius, color if visited or reachable else color.darkened(0.55))
		_view.draw_string(font, at + Vector2(-radius, 3.5), MapRoom.type_letter(room.type), HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 9, OUTLINE)
		if room.id == run.current_room_id:
			_view.draw_arc(at, radius + 3.0, 0.0, TAU, 24, Color.WHITE, 2.0)
		elif reachable:
			_view.draw_arc(at, radius + 2.0 + pulse * 2.0, 0.0, TAU, 24, Color(Color.WHITE, 0.4 + 0.6 * pulse), 1.5)
	_view.draw_multiline_string(font, Vector2(4.0, PANEL_RECT.size.y - 20.0), LEGEND, HORIZONTAL_ALIGNMENT_CENTER, PANEL_RECT.size.x - 8.0, 7, -1, Color(INK, 0.7))


func _pos(room: MapRoom) -> Vector2:
	return room_position(room.row, room.lane, run.map.get_row(room.row).size())


func _draw_link(from: Vector2, to: Vector2, walked: bool) -> void:
	_view.draw_line(from, to, Color(INK, 0.9) if walked else Color(INK, 0.22), 2.0 if walked else 1.0)
