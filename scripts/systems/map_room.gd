class_name MapRoom
extends RefCounted
## One room on a floor's branching map (docs/GDD.md Section 6.1). Rooms sit in rows;
## `lane` is the room's place in its row, left to right, and matches the door order.

const COMBAT: StringName = &"combat"
const ELITE: StringName = &"elite"
const TREASURE: StringName = &"treasure"
const REST: StringName = &"rest"
const MERCHANT: StringName = &"merchant"
const EVENT: StringName = &"event"
const MINI_BOSS: StringName = &"mini_boss"
const BOSS: StringName = &"boss"

## Rooms fought with a WaveDirector encounter.
const FIGHT_TYPES: Array[StringName] = [COMBAT, ELITE, MINI_BOSS, BOSS]

## Name on doors and the map. The letter keeps types readable without color.
const TYPE_INFO: Dictionary = {
	COMBAT: {"name": "Fight", "letter": "F", "color": Color(0.85, 0.42, 0.35)},
	ELITE: {"name": "Elite", "letter": "E", "color": Color(0.9, 0.3, 0.75)},
	TREASURE: {"name": "Treasure", "letter": "T", "color": Color(1.0, 0.82, 0.35)},
	REST: {"name": "Rest", "letter": "R", "color": Color(0.45, 0.85, 0.5)},
	MERCHANT: {"name": "Merchant", "letter": "M", "color": Color(0.4, 0.7, 1.0)},
	EVENT: {"name": "Event", "letter": "?", "color": Color(0.75, 0.65, 1.0)},
	MINI_BOSS: {"name": "Mini-boss", "letter": "B", "color": Color(1.0, 0.55, 0.2)},
	BOSS: {"name": "Boss", "letter": "B", "color": Color(1.0, 0.25, 0.2)},
}

var id: int
var row: int
var lane: int
var type: StringName = COMBAT
## Ids of the rooms in the next row this room leads to.
var next: Array[int] = []


func _init(room_id: int = 0, room_row: int = 0, room_lane: int = 0) -> void:
	id = room_id
	row = room_row
	lane = room_lane


func is_fight() -> bool:
	return FIGHT_TYPES.has(type)


static func type_name(room_type: StringName) -> String:
	return TYPE_INFO.get(room_type, {}).get("name", String(room_type))


static func type_letter(room_type: StringName) -> String:
	return TYPE_INFO.get(room_type, {}).get("letter", "?")


static func type_color(room_type: StringName) -> Color:
	return TYPE_INFO.get(room_type, {}).get("color", Color.WHITE)
