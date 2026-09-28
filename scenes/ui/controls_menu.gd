class_name ControlsMenu
extends Control
## Controls remapping (docs/GDD.md Section 13, Settings). Pick an action's keyboard or
## gamepad slot, then press the new key or button within a few seconds. Taking an input
## another action uses swaps the two. Changes save at once and load at every boot.

signal closed

const TITLE_SCENE: String = "res://scenes/main/title.tscn"
## Seconds to press the new input before the change is dropped.
const LISTEN_TIME: float = 5.0
## Inputs are ignored this long after a slot is picked, so the press that picked it
## (A, Enter, a click) is not taken as the new input.
const LISTEN_GRACE: float = 0.2
const INK: Color = Color(0.95, 0.9, 0.78)
const DIM: Color = Color(0.85, 0.8, 0.72)

## Where bindings are saved (tests point this elsewhere).
var settings_path: String = InputBindings.SETTINGS_PATH
## Where Back goes; empty just emits `closed`.
var back_scene: String = TITLE_SCENE

var _buttons: Dictionary = {}
var _listen_action: StringName = &""
var _listen_kind: int = -1
var _listen_left: float = 0.0
var _grace_left: float = 0.0
var _status: Label
var _first_button: Button


func _ready() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.12, 0.09, 0.07)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var title: Label = _label("Controls", 18, Color(1, 0.78, 0.45))
	title.position = Vector2(0, 6)
	title.size = Vector2(640, 24)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(110, 34)
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 1)
	add_child(grid)
	grid.add_child(_label("", 9, DIM))
	grid.add_child(_header("Keyboard / mouse"))
	grid.add_child(_header("Gamepad"))
	for row: Array in InputBindings.ACTIONS:
		var action: StringName = row[0]
		var name_label: Label = _label(row[1], 9, INK)
		name_label.custom_minimum_size = Vector2(90, 0)
		grid.add_child(name_label)
		for kind: int in [InputBindings.Kind.KEYBOARD, InputBindings.Kind.GAMEPAD]:
			var button: Button = _compact_button(Vector2(150, 15))
			button.pressed.connect(start_listening.bind(action, kind))
			grid.add_child(button)
			_buttons[[action, kind]] = button
			if _first_button == null:
				_first_button = button
	_status = _label("", 9, DIM)
	_status.position = Vector2(0, 296)
	_status.size = Vector2(640, 16)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_status)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.position = Vector2(140, 318)
	footer.size = Vector2(360, 20)
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 12)
	add_child(footer)
	var reset: Button = _footer_button("Reset to defaults", _on_reset_pressed)
	reset.name = "ResetButton"
	footer.add_child(reset)
	var rumble: Button = _footer_button("Test rumble", func() -> void: _set_status(test_rumble()))
	rumble.name = "RumbleButton"
	footer.add_child(rumble)
	var back: Button = _footer_button("Back", close)
	back.name = "BackButton"
	footer.add_child(back)
	refresh()
	_set_status("Pick an input to change it. Esc / B goes back.")
	_first_button.grab_focus()


func refresh() -> void:
	for key: Array in _buttons:
		var button: Button = _buttons[key]
		button.text = InputBindings.event_name(InputBindings.primary(key[0], key[1]))


## Rumbles every connected gamepad for half a second and says what happened, so a pad
## that cannot rumble (or is not seen at all) is easy to spot.
func test_rumble() -> String:
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		return "No gamepad found. Plug one in and try again."
	var lines: PackedStringArray = []
	for pad: int in pads:
		if Input.has_joy_vibration(pad):
			Input.start_joy_vibration(pad, 1.0, 1.0, 0.5)
			lines.append("%s: rumbling" % Input.get_joy_name(pad))
		else:
			lines.append("%s: this pad cannot rumble" % Input.get_joy_name(pad))
	return ", ".join(lines)


func is_listening() -> bool:
	return _listen_action != &""


func start_listening(action: StringName, kind: int) -> void:
	_listen_action = action
	_listen_kind = kind
	_listen_left = LISTEN_TIME
	_grace_left = LISTEN_GRACE
	(_buttons[[action, kind]] as Button).text = "Press..."
	_update_listen_status()


func stop_listening(message: String) -> void:
	_listen_action = &""
	_listen_kind = -1
	refresh()
	_set_status(message)


func close() -> void:
	if back_scene.is_empty():
		closed.emit()
	else:
		SceneRouter.go(back_scene)


func _process(delta: float) -> void:
	if not is_listening():
		return
	_grace_left -= delta
	_listen_left -= delta
	if _listen_left <= 0.0:
		stop_listening("No change.")
	else:
		_update_listen_status()


func _input(event: InputEvent) -> void:
	if not is_listening() or InputBindings.kind_of(event) < 0:
		return
	get_viewport().set_input_as_handled()
	if _grace_left > 0.0 or not InputBindings.accepts(event, _listen_kind):
		return
	var action: StringName = _listen_action
	var taken: StringName = InputBindings.rebind(action, event)
	InputBindings.save(settings_path)
	var message: String = "%s: %s" % [_action_label(action), InputBindings.event_name(InputBindings.primary(action, _listen_kind))]
	if taken != &"":
		message += "   (%s now uses %s)" % [_action_label(taken), InputBindings.event_name(InputBindings.primary(taken, _listen_kind))]
	var button: Button = _buttons[[action, _listen_kind]]
	stop_listening(message)
	button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_listening() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_reset_pressed() -> void:
	InputBindings.reset_to_defaults()
	InputBindings.save(settings_path)
	stop_listening("All controls are back to the defaults.")


func _update_listen_status() -> void:
	var what: String = "key or mouse button" if _listen_kind == InputBindings.Kind.KEYBOARD else "gamepad button"
	_set_status("Press a %s for %s  (%d)" % [what, _action_label(_listen_action), ceili(_listen_left)])


func _set_status(text: String) -> void:
	_status.text = text


func _action_label(action: StringName) -> String:
	for row: Array in InputBindings.ACTIONS:
		if row[0] == action:
			return row[1]
	return String(action)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _header(text: String) -> Label:
	var label: Label = _label(text, 9, Color(1, 0.78, 0.45))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _footer_button(text: String, callback: Callable) -> Button:
	var button: Button = _compact_button(Vector2(110, 16))
	button.text = text
	button.pressed.connect(callback)
	return button


## A small flat button so all actions fit on one screen.
func _compact_button(min_size: Vector2) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = min_size
	button.add_theme_font_size_override(&"font_size", 9)
	var looks: Dictionary = {
		&"normal": Color(0.2, 0.16, 0.13), &"hover": Color(0.3, 0.24, 0.19),
		&"pressed": Color(0.4, 0.3, 0.2), &"focus": Color(0, 0, 0, 0),
	}
	for state: StringName in looks:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = looks[state]
		box.set_content_margin_all(1.0)
		box.set_corner_radius_all(2)
		if state == &"focus":
			box.draw_center = false
			box.border_color = Color(1, 0.78, 0.45)
			box.set_border_width_all(1)
		button.add_theme_stylebox_override(state, box)
	return button
