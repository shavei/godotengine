extends CanvasLayer
## Dev-only live tuning menu for combat feel (docs/ARCHITECTURE.md Section 11).
## Open it with Start in the Tuning room, or F4 in any room (debug builds). The game
## pauses while it is open; close it to feel a change, open it again to adjust.
## Controller: D-pad or left stick picks a row and changes a number (hold RB for 5x),
## X resets the number, A runs an action, B or Start closes.
## Keyboard: arrows, Shift for 5x, Backspace resets, Enter runs an action, Esc or F4 closes.
## "Save results" writes the numbers to the .tres file (so the change shows up in GitHub
## Desktop when the game runs from the editor), copies a summary to the clipboard,
## writes it to user://tuning_results.txt and prints it to Output.

signal opened
signal closed

const TOGGLE_KEY: Key = KEY_F4
## Tunable BalanceData numbers: [property, step per press, label].
const ROWS: Array[Array] = [
	[&"hero_move_speed", 5.0, "Move speed"],
	[&"hero_acceleration", 50.0, "Acceleration"],
	[&"hero_friction", 50.0, "Friction (stopping)"],
	[&"attack_move_scale", 0.05, "Move while attacking"],
	[&"dodge_distance", 4.0, "Dodge distance"],
	[&"dodge_duration", 0.02, "Dodge time"],
	[&"dodge_iframes", 0.02, "Dodge invincibility"],
	[&"dodge_stamina_cost", 1.0, "Dodge stamina cost"],
	[&"stamina_regen", 5.0, "Stamina regen / s"],
	[&"stamina_regen_delay", 0.05, "Stamina regen delay"],
	[&"hurt_stun", 0.02, "Hurt stun"],
	[&"hurt_iframes", 0.05, "Invincible after hit"],
	[&"input_buffer", 0.01, "Input buffer"],
	[&"combo_reset", 0.05, "Combo reset time"],
	[&"flask_drink_time", 0.05, "Flask drink time"],
	[&"flask_move_scale", 0.05, "Move while drinking"],
	[&"flask_heal_fraction", 0.05, "Flask heal"],
	[&"aim_assist_angle", 5.0, "Aim assist angle"],
	[&"aim_assist_range", 4.0, "Aim assist range"],
	[&"rumble_strength", 0.1, "Rumble strength"],
]
const SHIFT_STEPS: float = 5.0
## A held direction repeats after this long, then every REPEAT_RATE (real seconds).
const REPEAT_DELAY: float = 0.35
const REPEAT_RATE: float = 0.07
const RESULTS_PATH: String = "user://tuning_results.txt"

var balance: BalanceData
var selected: int = 0
## Last message shown under the list (saved, reset, ...).
var status_text: String = ""

## Values when the panel was bound (game start): reset targets and the "was" in results.
var _defaults: Dictionary = {}
## Extra menu actions: [label, Callable]. Save, Reset all and Close are always there.
var _actions: Array[Array] = []
var _text: RichTextLabel
var _held: Vector2i = Vector2i.ZERO
var _next_repeat_ms: int = 0


func _ready() -> void:
	layer = 127
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process(false)
		set_process_input(false)
		return
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0.03, 0.02, 0.04, 0.88)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(404, 8)
	panel.size = Vector2(228, 344)
	add_child(panel)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = false
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.position = Vector2(6, 4)
	_text.size = panel.size - Vector2(12, 8)
	_text.add_theme_font_size_override("normal_font_size", 8)
	_text.add_theme_constant_override("line_separation", -2)
	_text.add_theme_color_override("default_color", Color(1.0, 0.92, 0.7))
	panel.add_child(_text)
	bind(ContentDB.get_item(&"balance", &"default") as BalanceData)


## Points the panel at `data` and remembers its current numbers as the defaults.
func bind(data: BalanceData) -> void:
	balance = data
	_defaults.clear()
	if balance != null:
		for row: Array in ROWS:
			_defaults[row[0]] = balance.get(row[0])
	_refresh()


## Opens the menu and pauses the game. `actions` adds rows like ["Spawn enemies", callable].
func open(actions: Array[Array] = []) -> void:
	if _text == null:
		return
	_actions = actions
	selected = clampi(selected, 0, row_count() - 1)
	visible = true
	get_tree().paused = true
	_held = _read_direction()
	_refresh()
	opened.emit()


func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false
	if not changes().is_empty():
		print("[Tuning] changes so far:\n%s" % changes())
	closed.emit()


func is_open() -> bool:
	return visible


## Number rows first, then the action rows.
func row_count() -> int:
	return ROWS.size() + _all_actions().size()


func select(index: int) -> void:
	selected = wrapi(index, 0, row_count())
	_refresh()


## Changes the selected number by `steps` of its step size (never below 0).
func adjust(steps: float) -> void:
	if balance == null or selected >= ROWS.size():
		return
	var property: StringName = ROWS[selected][0]
	var value: float = maxf(0.0, snappedf(balance.get(property) + ROWS[selected][1] * steps, 0.001))
	_set_value(property, value)


func reset_selected() -> void:
	if balance == null or selected >= ROWS.size():
		return
	var property: StringName = ROWS[selected][0]
	_set_value(property, _defaults[property])


func reset_all() -> void:
	if balance == null:
		return
	for row: Array in ROWS:
		balance.set(row[0], _defaults[row[0]])
	_apply_to_heroes()
	status_text = "All numbers back to where they started."
	print("[Tuning] reset all")
	_refresh()


## Runs the selected action row (Save results, Reset all, a room action or Close).
func activate() -> void:
	var index: int = selected - ROWS.size()
	var actions: Array[Array] = _all_actions()
	if index < 0 or index >= actions.size():
		return
	(actions[index][1] as Callable).call()


## Every number that differs from its start value, one `name: old -> new` line each.
func changes() -> String:
	var lines: PackedStringArray = []
	if balance == null:
		return ""
	for row: Array in ROWS:
		var value: float = balance.get(row[0])
		if not is_equal_approx(value, _defaults[row[0]]):
			lines.append("%s: %s -> %s" % [row[0], format_number(_defaults[row[0]]), format_number(value)])
	return "\n".join(lines)


## The summary that Save copies to the clipboard: changes plus every current number.
func results_text() -> String:
	var lines: PackedStringArray = ["Tuning results (%s)" % Time.get_datetime_string_from_system(false, true)]
	var changed: String = changes()
	lines.append("Changed:")
	lines.append(changed if not changed.is_empty() else "(nothing)")
	lines.append("All numbers:")
	for row: Array in ROWS:
		lines.append("%s = %s" % [row[0], format_number(balance.get(row[0]))])
	return "\n".join(lines)


## Writes the numbers to the BalanceData's .tres, the summary to RESULTS_PATH and the
## clipboard. Returns the .tres save result (it only works when run from the editor).
func save() -> Error:
	var summary: String = results_text()
	print("[Tuning] %s" % summary)
	if DisplayServer.get_name() != "headless":
		DisplayServer.clipboard_set(summary)
	var file: FileAccess = FileAccess.open(RESULTS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(summary + "\n")
		file.close()
	var err: Error = write_tres(balance.resource_path)
	if err == OK:
		status_text = "Saved to %s. Commit it in GitHub Desktop. Summary copied to the clipboard." % balance.resource_path.trim_prefix("res://")
	else:
		status_text = "Could not write the game file (error %d). Summary is in the clipboard and %s." % [
			err, ProjectSettings.globalize_path(RESULTS_PATH)]
		printerr("[Tuning] could not save %s (error %d)" % [balance.resource_path, err])
	_refresh()
	return err


## A float as the .tres writes it, without rounding noise: 0.7, 72.0, 0.15.
func format_number(value: float) -> String:
	var text: String = String.num(value, 3)
	return text if text.contains(".") else text + ".0"


## Updates only the tuned lines of the .tres at `path`, so the file keeps every other
## value and the GitHub diff shows just what changed. (ResourceSaver would drop every
## value that equals the script default.) A new file is written whole if none exists.
func write_tres(path: String) -> Error:
	if not FileAccess.file_exists(path):
		return ResourceSaver.save(balance, path)
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	var resource_line: int = lines.find("[resource]")
	if resource_line < 0:
		return ERR_FILE_UNRECOGNIZED
	for row: Array in ROWS:
		var entry: String = "%s = %s" % [row[0], format_number(balance.get(row[0]))]
		var found: bool = false
		for i: int in range(resource_line + 1, lines.size()):
			if lines[i].begins_with("%s = " % row[0]):
				lines[i] = entry
				found = true
				break
		if not found:
			var last: int = lines.size() - 1
			while last > resource_line and lines[last].strip_edges().is_empty():
				last -= 1
			lines.insert(last + 1, entry)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	file.close()
	return OK


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == TOGGLE_KEY:
		if visible:
			close()
		else:
			open(_actions)
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		close()
	elif event.is_action_pressed(&"ui_accept"):
		activate()
	elif _is_reset_press(event):
		reset_selected()
	# The game is paused, but nothing behind the menu should see its input.
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not visible:
		return
	# Directions are polled so a held D-pad or stick repeats (joypad buttons do not echo).
	# Real time, because hit-stop may have slowed the engine clock.
	var dir: Vector2i = _read_direction()
	var now: int = Time.get_ticks_msec()
	if dir != _held:
		_held = dir
		_next_repeat_ms = now + int(REPEAT_DELAY * 1000.0)
		_step(dir)
	elif dir != Vector2i.ZERO and now >= _next_repeat_ms:
		_next_repeat_ms = now + int(REPEAT_RATE * 1000.0)
		_step(dir)


func _step(dir: Vector2i) -> void:
	if dir.y != 0:
		select(selected + dir.y)
	elif dir.x != 0:
		adjust(float(dir.x) * (SHIFT_STEPS if _fast_held() else 1.0))


func _read_direction() -> Vector2i:
	var y: int = int(Input.is_action_pressed(&"ui_down")) - int(Input.is_action_pressed(&"ui_up"))
	var x: int = int(Input.is_action_pressed(&"ui_right")) - int(Input.is_action_pressed(&"ui_left"))
	return Vector2i(x, 0) if y == 0 else Vector2i(0, y)


func _fast_held() -> bool:
	if Input.is_key_pressed(KEY_SHIFT):
		return true
	for device: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER):
			return true
	return false


func _is_reset_press(event: InputEvent) -> bool:
	var button: InputEventJoypadButton = event as InputEventJoypadButton
	if button != null:
		return button.pressed and button.button_index == JOY_BUTTON_X
	var key: InputEventKey = event as InputEventKey
	return key != null and key.pressed and key.physical_keycode == KEY_BACKSPACE


func _all_actions() -> Array[Array]:
	var actions: Array[Array] = [["Save results", save], ["Reset all", reset_all]]
	actions.append_array(_actions)
	actions.append(["Close", close])
	return actions


func _set_value(property: StringName, value: float) -> void:
	var old: float = balance.get(property)
	balance.set(property, value)
	print("[Tuning] %s = %s (was %s)" % [property, format_number(value), format_number(old)])
	status_text = ""
	_apply_to_heroes()
	_refresh()


func _apply_to_heroes() -> void:
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
		var hero: Hero = node as Hero
		if hero != null and hero.balance == balance:
			hero.apply_balance()


func _refresh() -> void:
	if _text == null or not visible:
		return
	var lines: PackedStringArray = [
		"[color=#ffc86e]TUNING[/color]   [color=#b8a888]up/down pick   left/right change (hold RB x5)[/color]"]
	if balance == null:
		lines.append("No balance data loaded")
	else:
		for i: int in ROWS.size():
			var property: StringName = ROWS[i][0]
			var value: float = balance.get(property)
			var changed: bool = not is_equal_approx(value, _defaults[property])
			var line: String = "%s  %s%s" % [ROWS[i][2], format_number(value), "  (was %s)" % format_number(_defaults[property]) if changed else ""]
			lines.append(_row_line(i, line, changed))
	var actions: Array[Array] = _all_actions()
	for i: int in actions.size():
		lines.append(_row_line(ROWS.size() + i, "[ %s ]" % actions[i][0], false))
	lines.append("[color=#b8a888]X reset number   A choose   B / Start close[/color]")
	if not status_text.is_empty():
		lines.append("[color=#9fe07a]%s[/color]" % status_text)
	_text.text = "\n".join(lines)


func _row_line(index: int, text: String, changed: bool) -> String:
	if index == selected:
		return "[bgcolor=#5a4630][color=#ffffff]> %s[/color][/bgcolor]" % text
	if changed:
		return "  [color=#ffd27a]%s[/color]" % text
	return "  %s" % text
