class_name EncounterData
extends Resource
## A combat room's waves (docs/GDD.md Section 6: combat rooms have 3 to 4 waves).

@export var id: StringName
@export var display_name: String
@export var waves: Array[WaveData] = []
## Pause between clearing a wave and the next one's spawn warnings (s).
@export var wave_delay: float = 1.2
