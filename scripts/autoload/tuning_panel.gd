extends CanvasLayer
## Dev-only live tuning for combat feel (docs/ARCHITECTURE.md Section 11). Press F4 in a
## debug build. Changes edit the loaded BalanceData, so they apply while you play.
## Keys: Page Up / Page Down pick a number, - and = change it (hold Shift for 5x),
## Backspace resets it, Enter saves every change to the .tres file.
## Every change is printed to the Output panel so it can be copied into feedback.

const TOGGLE_KEY: Key = KEY_F4
## Tunable BalanceData numbers and their step per key press.
const ROWS: Array[Array] = [
	[&"hero_move_speed", 5.0],
	[&"hero_acceleration", 50.0],
	[&"hero_friction", 50.0],
	[&"dodge_distance", 4.0],
	[&"dodge_duration", 0.02],
	[&"dodge_iframes", 0.02],
	[&"dodge_stamina_cost", 1.0],
	[&"stamina_regen", 5.0],
	[&"stamina_regen_delay", 0.05],
	[&"hurt_stun", 0.02],
	[&"hurt_iframes", 0.05],
	[&"input_buffer", 0.01],
	[&"combo_reset", 0.05],
	[&"flask_drink_time", 0.05],
	[&"flask_move_scale", 0.05],
	[&"flask_heal_fraction", 0.05],
	[&"aim_assist_angle", 5.0],
	[&"aim_assist_range", 4.0],
	[&"rumble_strength", 0.1],
]
const SHIFT_STEPS: float = 5.0

var balance: BalanceData
var selected: int = 0

var _defaults: Dictionary = {}
var _label: Label


func _ready() -> void:
	layer = 127
	visible = false
	if not OS.is_debug_build():
		set_process_input(false)
		return
	var panel: ColorRect = ColorRect.new()
	panel.color = Color(0, 0, 0, 0.75)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.position = Vector2(468, 24)
	panel.size = Vector2(168, 208)
	add_child(panel)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.position = Vector2(4, 3)
	_label.add_theme_font_size_override("font_size", 8)
	_label.add_theme_constant_override("line_spacing", -2)
	_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	panel.add_child(_label)
	bind(ContentDB.get_item(&"balance", &"default") as BalanceData)


## Points the panel at `data` and remembers its current numbers as the defaults.
func bind(data: BalanceData) -> void:
	balance = data
	_defaults.clear()
	if balance != null:
		for row: Array in ROWS:
			_defaults[row[0]] = balance.get(row[0])
	_refresh()


func _input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
	if code == TOGGLE_KEY and not key.echo:
		visible = not visible
		if not visible and not changes().is_empty():
			print("[Tuning] changes so far:\n%s" % changes())
		_refresh()
		return
	if not visible or balance == null:
		return
	var steps: float = SHIFT_STEPS if key.shift_pressed else 1.0
	match code:
		KEY_PAGEUP:
			select(selected - 1)
		KEY_PAGEDOWN:
			select(selected + 1)
		KEY_MINUS, KEY_KP_SUBTRACT:
			adjust(-steps)
		KEY_EQUAL, KEY_KP_ADD:
			adjust(steps)
		KEY_BACKSPACE:
			reset_selected()
		KEY_ENTER, KEY_KP_ENTER:
			if not key.echo:
				save()
		_:
			return
	get_viewport().set_input_as_handled()


func select(index: int) -> void:
	selected = wrapi(index, 0, ROWS.size())
	_refresh()


## Changes the selected number by `steps` of its step size (never below 0).
func adjust(steps: float) -> void:
	var property: StringName = ROWS[selected][0]
	var value: float = maxf(0.0, snappedf(balance.get(property) + ROWS[selected][1] * steps, 0.001))
	_set_value(property, value)


func reset_selected() -> void:
	var property: StringName = ROWS[selected][0]
	_set_value(property, _defaults[property])


## Every number that differs from its default, one `name = value` line each.
func changes() -> String:
	var lines: PackedStringArray = []
	if balance == null:
		return ""
	for row: Array in ROWS:
		var value: float = balance.get(row[0])
		if not is_equal_approx(value, _defaults[row[0]]):
			lines.append("%s = %s (was %s)" % [row[0], value, _defaults[row[0]]])
	return "\n".join(lines)


## Writes the BalanceData back to its file (works when run from the editor).
func save() -> Error:
	var err: Error = ResourceSaver.save(balance, balance.resource_path)
	if err == OK:
		print("[Tuning] saved %s:\n%s" % [balance.resource_path, changes()])
		bind(balance)
	else:
		printerr("[Tuning] could not save %s (error %d)" % [balance.resource_path, err])
	return err


func _set_value(property: StringName, value: float) -> void:
	var old: float = balance.get(property)
	balance.set(property, value)
	print("[Tuning] %s = %s (was %s)" % [property, value, old])
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP):
		var hero: Hero = node as Hero
		if hero != null and hero.balance == balance:
			hero.apply_balance()
	_refresh()


func _refresh() -> void:
	if _label == null or not visible:
		return
	var lines: PackedStringArray = ["Tuning (F4)  PgUp/PgDn  - =  Bksp  Enter"]
	if balance == null:
		lines.append("No balance data loaded")
	else:
		for i: int in ROWS.size():
			var property: StringName = ROWS[i][0]
			var value: float = balance.get(property)
			var changed: String = "*" if not is_equal_approx(value, _defaults[property]) else " "
			lines.append("%s%s %s  %s" % [">" if i == selected else " ", changed, property, value])
	_label.text = "\n".join(lines)
