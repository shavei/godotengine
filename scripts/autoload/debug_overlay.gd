extends CanvasLayer
## Dev-only input inspector (docs/ARCHITECTURE.md Section 11). Press F3 in a debug build.
## Shows where the mouse is, which control is under it, the last click and key, and
## whether the window has focus. While visible, every mouse click is also printed to
## the Output panel so it can be copied into a bug report.
## Every node here ignores the mouse, so the overlay can never block clicks itself.

const TOGGLE_KEY: Key = KEY_F3

var _label: Label
var _last_click: String = "none yet"
var _last_key: String = "none yet"
var _clicks: int = 0


func _ready() -> void:
	layer = 128
	visible = false
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.7)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(4, 4)
	panel.size = Vector2(250, 100)
	add_child(panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(8, 6)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	panel.add_child(_label)


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		_last_key = OS.get_keycode_string(key.keycode if key.keycode != KEY_NONE else key.physical_keycode)
		if key.physical_keycode == TOGGLE_KEY or key.keycode == TOGGLE_KEY:
			visible = not visible
			print("[DebugOverlay] %s | %s" % ["shown" if visible else "hidden", describe().replace("\n", " | ")])
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null:
		_clicks += 1
		_last_click = "#%d button %d %s at %s" % [
			_clicks, button.button_index, "down" if button.pressed else "up", button.position.round()]
		if visible:
			print("[DebugOverlay] click %s | under mouse: %s | focus: %s | window focused: %s" % [
				_last_click, _control_name(get_viewport().gui_get_hovered_control()),
				_control_name(get_viewport().gui_get_focus_owner()), get_window().has_focus()])


func _process(_delta: float) -> void:
	if visible:
		_label.text = describe()


## One block of text with everything useful for an input bug report.
func describe() -> String:
	var viewport: Viewport = get_viewport()
	var window: Window = get_window()
	var scene: Node = get_tree().current_scene
	var lines: PackedStringArray = [
		"Input debug (F3 to hide)",
		"Window %s, focused: %s, embedded in editor: %s" % [
			window.size, window.has_focus(), Engine.is_embedded_in_editor()],
		"Mouse (game coords): %s" % viewport.get_mouse_position().round(),
		"Under mouse: %s" % _control_name(viewport.gui_get_hovered_control()),
		"Keyboard focus: %s" % _control_name(viewport.gui_get_focus_owner()),
		"Last click: %s" % _last_click,
		"Last key: %s" % _last_key,
		"Scene: %s, router busy: %s" % [
			String(scene.name) if scene != null else "none", SceneRouter.is_busy()],
	]
	return "\n".join(lines)


func _control_name(control: Control) -> String:
	if control == null:
		return "nothing"
	var filter: String = ["stop", "pass", "ignore"][control.mouse_filter]
	return "%s (%s, mouse %s)" % [control.name, control.get_class(), filter]
