extends GutTest
## AimAssist rules: stick attacks turn toward a close target inside a small cone.


func _targets(points: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Vector2 in points:
		out.append(p)
	return out


func test_turns_toward_target_inside_cone() -> void:
	var aim: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(20))
	var dir: Vector2 = AimAssist.pick(Vector2.ZERO, aim, _targets([Vector2(40, 0)]), 30.0, 64.0)
	assert_almost_eq(dir.angle(), 0.0, 0.001)
	assert_almost_eq(dir.length(), 1.0, 0.001)


func test_ignores_target_outside_cone() -> void:
	var aim: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(40))
	var dir: Vector2 = AimAssist.pick(Vector2.ZERO, aim, _targets([Vector2(40, 0)]), 30.0, 64.0)
	assert_almost_eq(dir.angle(), aim.angle(), 0.001)


func test_ignores_target_out_of_range() -> void:
	var dir: Vector2 = AimAssist.pick(Vector2.ZERO, Vector2.UP, _targets([Vector2(0, -80)]), 30.0, 64.0)
	assert_eq(dir, Vector2.UP)
	var near: Vector2 = AimAssist.pick(Vector2.ZERO, Vector2.UP.rotated(0.2), _targets([Vector2(0, -60)]), 30.0, 64.0)
	assert_almost_eq(near.angle(), Vector2.UP.angle(), 0.001)


func test_prefers_target_nearest_the_aim_line() -> void:
	var on_line: Vector2 = Vector2(50, 2)
	var closer_but_off: Vector2 = Vector2(20, 10)
	var dir: Vector2 = AimAssist.pick(Vector2.ZERO, Vector2.RIGHT, _targets([closer_but_off, on_line]), 30.0, 64.0)
	assert_almost_eq(dir.angle(), on_line.angle(), 0.001)


func test_zero_angle_or_range_turns_it_off() -> void:
	var aim: Vector2 = Vector2.RIGHT.rotated(0.2)
	assert_eq(AimAssist.pick(Vector2.ZERO, aim, _targets([Vector2(40, 0)]), 0.0, 64.0), aim)
	assert_eq(AimAssist.pick(Vector2.ZERO, aim, _targets([Vector2(40, 0)]), 30.0, 0.0), aim)


func test_no_aim_stays_zero() -> void:
	assert_eq(AimAssist.pick(Vector2.ZERO, Vector2.ZERO, _targets([Vector2(40, 0)]), 30.0, 64.0), Vector2.ZERO)
