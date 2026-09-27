class_name HitFlash
extends RefCounted
## Flashes a CanvasItem that uses assets/shaders/hit_flash.gdshader.
## The material must be local to the scene so each actor flashes on its own.

const PARAM: String = "shader_parameter/flash"


static func play(item: CanvasItem, duration: float = 0.12) -> void:
	var material: ShaderMaterial = item.material as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("flash", 1.0)
	var tween: Tween = item.create_tween()
	tween.tween_property(material, PARAM, 0.0, duration)
