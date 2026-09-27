extends GutTest
## Guards the display and rendering settings from docs/GDD.md Section 1.5 and CLAUDE.md.


func test_base_resolution_is_640x360() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 640)
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 360)


func test_integer_scaling_for_pixel_art() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/scale_mode"), "integer")


func test_physics_interpolation_for_smooth_motion() -> void:
	assert_true(ProjectSettings.get_setting("physics/common/physics_interpolation"))


func test_nearest_texture_filter() -> void:
	assert_eq(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0)


func test_collision_layer_names() -> void:
	var expected: Array[String] = [
		"world", "hero_body", "enemy_body", "hero_hitbox", "enemy_hitbox",
		"hero_hurtbox", "enemy_hurtbox", "pickups", "buildings",
	]
	for i: int in expected.size():
		var key: String = "layer_names/2d_physics/layer_%d" % (i + 1)
		assert_eq(ProjectSettings.get_setting(key), expected[i], key)
