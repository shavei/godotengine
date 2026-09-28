extends Node
## Global signals only. No state lives here.
## Systems and scenes emit and subscribe; nothing references scene nodes directly.

# Other scripts emit these signals, so Godot's "declared but never used in the class"
# warning is expected here and silenced for the whole file.
@warning_ignore_start("unused_signal")

# The Choice
signal power_kept(player_id: int, power_id: StringName)
signal power_given(player_id: int, power_id: StringName, villager_index: int)
signal power_merged(player_id: int, power_id: StringName, new_level: int)
## A kept power was raised a level with Power Shards.
signal power_leveled(player_id: int, power_id: StringName, new_level: int)

# Village
signal villager_ranked_up(villager_index: int, new_rank: int)
signal technique_learned(player_id: int, technique_id: StringName)
signal renown_changed(points: int, level: int)

# Runs
signal run_started(region_id: StringName, seed: int)
signal run_ended(success: bool)
signal room_cleared

# Raids
signal raid_started(faction_id: StringName)
signal raid_ended(success: bool)

# Game feel
signal camera_shake_requested(trauma: float)

# Combat
signal hero_died(player_id: int)

# Saving
signal game_saved(slot: int)
signal game_loaded(slot: int)
