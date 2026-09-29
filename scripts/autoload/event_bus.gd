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
## A power offer was settled, or a kept power given at the Shrine. `record` is a
## MetricsLog.choice_record() (power, level, action, villager, seconds on screen).
signal choice_made(player_id: int, record: Dictionary)
## The gift ceremony for a villager ended (watched to the end or skipped).
signal gift_ceremony_finished(villager_index: int)

# Village
signal villager_ranked_up(villager_index: int, new_rank: int)
signal technique_learned(player_id: int, technique_id: StringName)
signal renown_changed(points: int, level: int)
## Something was bought from a villager (a weapon tier or a service, by id).
signal village_purchase(player_id: int, item_id: StringName)

# Runs
signal run_started(region_id: StringName, seed: int)
signal run_ended(success: bool)
## One hero's results for a run that just ended (after run_ended).
signal run_summarized(summary: RunSummary)
signal room_cleared

# Raids
signal raid_started(faction_id: StringName)
signal raid_ended(success: bool)

# Game feel
signal camera_shake_requested(trauma: float)
## The player switched between keyboard/mouse and gamepad (InputBindings.Kind).
signal input_device_changed(kind: int)

# Combat
signal hero_died(player_id: int)
## A revive token brought the hero back up.
signal hero_revived(player_id: int)

# Saving
signal game_saved(slot: int)
signal game_loaded(slot: int)
