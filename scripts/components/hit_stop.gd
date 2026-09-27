class_name HitStop
extends RefCounted
## Brief freeze on heavy hits (docs/GDD.md Section 7.2) by pulsing Engine.time_scale.
## Overlapping requests extend the freeze; the last one to finish restores normal speed.

## Accessibility toggle (docs/GDD.md Section 18). The Settings menu will own this in M7.
static var enabled: bool = true
static var frozen_scale: float = 0.05

static var _end_msec: int = 0
static var _latest: int = 0


static func request(tree: SceneTree, duration: float) -> void:
	if not enabled or duration <= 0.0:
		return
	var end_msec: int = Time.get_ticks_msec() + int(duration * 1000.0)
	if end_msec <= _end_msec:
		return
	_end_msec = end_msec
	_latest += 1
	var ticket: int = _latest
	Engine.time_scale = frozen_scale
	# ignore_time_scale: the timer runs in real time while the game is frozen.
	await tree.create_timer(duration, true, false, true).timeout
	# Only the newest request restores speed. Comparing clocks here is unsafe: the
	# timer can finish a millisecond before end_msec and leave the game frozen.
	if ticket == _latest:
		Engine.time_scale = 1.0
		_end_msec = 0


static func is_active() -> bool:
	return Engine.time_scale < 1.0 and _end_msec > 0
