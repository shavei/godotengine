class_name TestShortcuts
extends RefCounted
## Rules behind the Test shortcuts screen (debug builds only): jump straight to what the
## owner's playtest checklist (docs/PLAYTEST_CHECKLIST.md) asks about, without playing
## the runs in between. Each profile change returns a line for the screen's status.


## A run that starts in front of a floor's exit fight: floor 0 is Mother Toad, the last
## floor the region boss. The room is entered but not cleared, as if the hero just
## walked in.
static func boss_run(region: RegionData, floor_index: int, seed_value: int) -> RunState:
	var run: RunState = RunState.start(region, seed_value)
	var target: int = clampi(floor_index, 0, region.floor_count - 1)
	while run.floor_index < target:
		run.current_room_id = run.map.exit_room().id
		run.room_cleared = true
		run.advance_floor()
	var exit: MapRoom = run.map.exit_room()
	run.current_room_id = exit.id
	run.path.append(exit.id)
	run.route.append("%d:%s" % [run.floor_index + 1, exit.type])
	run.room_cleared = false
	return run


## Adds `count` runs' worth of training: the village applies them on the next visit,
## exactly as after real runs (rank-ups, lessons and all).
static func add_training_runs(profile: ProfileState, count: int) -> String:
	profile.training_due += count
	profile.run_count += count
	return "+%d %s of training. Go to the village to see it." % [count, "run" if count == 1 else "runs"]


## Fills the hero's kept slots with these powers at `level` (replacing what was kept).
static func keep_powers(hero: HeroState, power_ids: Array[StringName], level: int, slots: int) -> String:
	hero.kept_powers.clear()
	var names: PackedStringArray = []
	for power_id: StringName in power_ids:
		if hero.kept_powers.size() >= slots:
			break
		hero.kept_powers.append(KeptPower.create(power_id, level))
		names.append(String(power_id).capitalize())
	return "Keeping %s at level %d." % [", ".join(names), level]
