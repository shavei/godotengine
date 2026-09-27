class_name RegionData
extends Resource
## A run region (docs/GDD.md Section 6, docs/CONTENT.md Section 6): floor shape, how
## often each room type appears, and the encounters its fight rooms draw from.

@export var id: StringName
@export var display_name: String
@export var floor_count: int = 3

@export_group("Floor map")
## Rows of rooms before the floor's exit (mini-boss or boss).
@export var min_depth: int = 5
@export var max_depth: int = 7
## Rooms side by side in a row.
@export var min_row_width: int = 2
@export var max_row_width: int = 3
## Chance to add each extra door between rows (beyond the one every room gets).
@export_range(0.0, 1.0) var branch_chance: float = 0.6
## Relative weights of room types (MapRoom constants). Mini-boss and boss rooms are
## always the floor exits and are not rolled.
@export var room_weights: Dictionary[StringName, float] = {}
## Elites never appear in rows before this one (0 = the first row).
@export var elite_min_row: int = 2

@export_group("Encounters")
@export var combat_encounters: Array[EncounterData] = []
@export var elite_encounters: Array[EncounterData] = []
## Floors before the last end here.
@export var mini_boss_encounter: EncounterData
## The last floor ends here.
@export var boss_encounter: EncounterData
@export var floor_color: Color = Color(0.2, 0.26, 0.19)
