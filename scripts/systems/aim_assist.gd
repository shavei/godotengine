class_name AimAssist
extends RefCounted
## Melee aim assist for sticks (docs/GDD.md Section 15.5): an attack aimed close to a
## nearby target turns to face it. Mouse aim is never assisted.

## Nodes in this group can pull an assisted attack toward them.
const GROUP: StringName = &"aim_assist_targets"


## Returns `aim`, or the direction to the best target within `max_angle_deg` of it and
## `max_range` px of `origin`. Targets nearest the aim line win, then nearer ones.
static func pick(origin: Vector2, aim: Vector2, targets: Array[Vector2], max_angle_deg: float, max_range: float) -> Vector2:
	if aim == Vector2.ZERO or max_angle_deg <= 0.0 or max_range <= 0.0:
		return aim
	var max_angle: float = deg_to_rad(max_angle_deg)
	var best: Vector2 = aim
	var best_score: float = INF
	for target: Vector2 in targets:
		var offset: Vector2 = target - origin
		var distance: float = offset.length()
		if distance < 0.001 or distance > max_range:
			continue
		var angle: float = absf(aim.angle_to(offset))
		if angle > max_angle:
			continue
		var score: float = angle / max_angle + distance / max_range
		if score < best_score:
			best_score = score
			best = offset
	return best.normalized()
