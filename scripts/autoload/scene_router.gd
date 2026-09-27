extends Node
## Scene transitions with a fade, passing a context Dictionary to the next scene.
## The next scene reads it with SceneRouter.context in its _ready().

const FADE_TIME: float = 0.25

## Context handed to the most recently loaded scene (region id, seed, results, ...).
var context: Dictionary = {}

var _fade_layer: CanvasLayer
var _fade_rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 100
	add_child(_fade_layer)
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade_rect)


func go(scene_path: String, new_context: Dictionary = {}) -> void:
	if _busy:
		return
	if not ResourceLoader.exists(scene_path):
		push_error("SceneRouter: no scene at %s" % scene_path)
		return
	_busy = true
	await _fade_to(1.0)
	context = new_context
	var err: Error = get_tree().change_scene_to_file(scene_path)
	if err == OK:
		await get_tree().scene_changed
	else:
		# No scene change will come, so do not wait for one: that would leave the
		# router busy forever and every later button press would be ignored.
		push_error("SceneRouter: could not load %s (%s)" % [scene_path, error_string(err)])
	await _fade_to(0.0)
	_busy = false


## True while a transition is running; go() calls are ignored until it ends.
func is_busy() -> bool:
	return _busy


func _fade_to(alpha: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_fade_rect, "modulate:a", alpha, FADE_TIME)
	await tween.finished
