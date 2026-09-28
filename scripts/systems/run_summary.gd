class_name RunSummary
extends RefCounted
## What one hero got out of a finished run, for the results screen (docs/GDD.md Section 13).

var player_id: int = 0
var success: bool = false
var region_name: String = ""
## 1-based floor the run ended on.
var floor_reached: int = 1
var floor_count: int = 3
var rooms_cleared: int = 0
var elapsed: float = 0.0
var xp_gained: int = 0
var level_before: int = 1
var level_after: int = 1
## XP into the new level and XP that level needs (0 at the cap).
var xp_into_level: int = 0
var xp_for_next: int = 0
## The weapon the hero dealt the most damage with (&"" if none).
var weapon_id: StringName = &""
var mastery_xp_gained: int = 0
var mastery_before: int = 1
var mastery_after: int = 1
## currency -> amount picked up during the run.
var found: Dictionary[StringName, int] = {}
## currency -> amount banked (all of it on a clear, a share after a fall).
var kept: Dictionary[StringName, int] = {}
var keep_fraction: float = 1.0


func levels_gained() -> int:
	return level_after - level_before


## Time as m:ss.
func time_text() -> String:
	var seconds: int = floori(elapsed)
	return "%d:%02d" % [floori(seconds / 60.0), seconds % 60]
