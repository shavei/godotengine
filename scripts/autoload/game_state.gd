extends Node
## Owns the current profile (village plus heroes keyed by player_id).
## Stub for M0: the typed ProfileState classes arrive in M2 to M4 (docs/ARCHITECTURE.md Section 4.2).
## Rule: never store per-player data directly on this node; key it by player_id.

const LOCAL_PLAYER_ID: int = 0

## Serializable profile data. Replaced by ProfileState in M4.
var profile: Dictionary = {}
## The run in progress, or null in the village and menus. Shared by the whole party;
## per-hero data inside it is keyed by player_id.
var run: RunState = null


func new_profile() -> void:
	profile = {
		"version": 1,
		"season": 0,
		"run_count": 0,
		"heroes": {str(LOCAL_PLAYER_ID): {}},
		"village": {},
		"codex": {},
	}


func has_profile() -> bool:
	return not profile.is_empty()
