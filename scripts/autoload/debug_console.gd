extends CanvasLayer
## Dev-only debug console (docs/ARCHITECTURE.md Section 11). Press ` (backtick) or F2 in a
## debug build. The game pauses while it is open. Type a command and press Enter; Up
## brings back the last one; Esc, ` or F2 closes. Commands: give_power fire,
## set_tp smith 7, add_renown 10, skip_room, god_mode, help (ConsoleCommands).
## A command that changes the profile saves it; in the village, closing the console
## shows the village again so rank-ups, lessons and Renown moments play.

signal opened
signal closed

const TOGGLE_KEYS: Array[Key] = [KEY_QUOTELEFT, KEY_F2]
const VILLAGE_SCENE: String = "res://scenes/village/village.tscn"
const MAX_LINES: int = 8
const INK: Color = Color(0.75, 1.0, 0.75)
const ERROR_INK: Color = Color(1.0, 0.6, 0.55)

## Save the profile after a command changes it (tests turn it off).
var save_on_change: bool = true
## Lines shown above the input, oldest first.
var lines: PackedStringArray = []

var _output: Label
var _line_edit: LineEdit
var _last_command: String = ""
var _was_paused: bool = false
## A command changed the profile: the village is shown again on close.
var _profile_changed: bool = false


func _ready() -> void:
	layer = 126
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_input(false)
		return
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.02, 0.03, 0.02, 1.0)
	panel.position = Vector2(0, 222)
	panel.size = Vector2(640, 138)
	add_child(panel)
	_output = Label.new()
	_output.position = Vector2(6, 2)
	_output.size = Vector2(628, 112)
	_output.clip_text = true
	_output.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_output.add_theme_font_size_override("font_size", 8)
	_output.add_theme_color_override("font_color", INK)
	_output.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_output)
	_line_edit = LineEdit.new()
	_line_edit.position = Vector2(4, 118)
	_line_edit.size = Vector2(632, 16)
	_line_edit.placeholder_text = "Type a command (help lists them)"
	_line_edit.add_theme_font_size_override("font_size", 8)
	_line_edit.text_submitted.connect(_on_submitted)
	panel.add_child(_line_edit)
	lines.append("Debug console. Type help for the commands.")
	_output.text = lines[0]


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if TOGGLE_KEYS.has(code) or (visible and code == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		if visible:
			close()
		elif not visible and code != KEY_ESCAPE:
			open()
	elif visible and code == KEY_UP and not _last_command.is_empty():
		get_viewport().set_input_as_handled()
		_line_edit.text = _last_command
		_line_edit.caret_column = _line_edit.text.length()


func open() -> void:
	if visible:
		return
	visible = true
	_was_paused = get_tree().paused
	get_tree().paused = true
	_line_edit.clear()
	_line_edit.grab_focus()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	_line_edit.release_focus()
	get_tree().paused = _was_paused
	closed.emit()
	if _profile_changed and get_tree().current_scene is Village:
		SceneRouter.go(VILLAGE_SCENE)
	_profile_changed = false


## Runs one command line and returns what it printed.
func run(line: String) -> String:
	var args: PackedStringArray = ConsoleCommands.words(line)
	if args.is_empty():
		return ""
	var text: String
	var ok: bool = true
	match args[0]:
		"skip_room":
			var room: RunRoom = get_tree().current_scene as RunRoom
			ok = room != null and room.skip_room()
			text = "Room cleared." if ok else "Only in a run room that is not clear yet."
		"god_mode":
			Hero.god_mode = not Hero.god_mode
			for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
				(node as Hero).health.invulnerable = Hero.god_mode
			text = "God mode %s." % ("on" if Hero.god_mode else "off")
		_:
			var result: Dictionary = ConsoleCommands.run(args, GameState.profile, GameState.LOCAL_PLAYER_ID,
					GameState.balance(), _powers())
			ok = result["ok"]
			text = result["text"]
			if result["changed"]:
				_profile_changed = true
				if save_on_change:
					GameState.save_profile()
	print_line("> " + line.strip_edges())
	print_line(text, ok)
	return text


## Adds a line (or several) to the output, keeping the last MAX_LINES.
func print_line(text: String, ok: bool = true) -> void:
	if text.is_empty():
		return
	for part: String in text.split("\n"):
		lines.append(part)
	while lines.size() > MAX_LINES:
		lines.remove_at(0)
	if _output != null:
		_output.text = "\n".join(lines)
		_output.add_theme_color_override("font_color", INK if ok else ERROR_INK)
	print("[DebugConsole] %s" % text.replace("\n", " | "))


func _powers() -> Array[PowerData]:
	var result: Array[PowerData] = []
	for item: Resource in ContentDB.get_all(&"powers"):
		if item is PowerData:
			result.append(item)
	return result


func _on_submitted(line: String) -> void:
	if not line.strip_edges().is_empty():
		_last_command = line
	run(line)
	_line_edit.clear()
