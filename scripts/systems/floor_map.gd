class_name FloorMap
extends RefCounted
## A floor's branching map: rows of rooms, each leading to one or more rooms in the
## next row, and a single exit room (mini-boss or boss) at the end. Built by RunGenerator.

var floor_index: int = 0
## Rows of rooms; the last row holds only the exit room.
var rows: Array[Array] = []
## Every room, indexed by id.
var rooms: Array[MapRoom] = []


func add_row(count: int) -> Array[MapRoom]:
	var row_index: int = rows.size()
	var row_rooms: Array[MapRoom] = []
	for lane: int in count:
		var room: MapRoom = MapRoom.new(rooms.size(), row_index, lane)
		rooms.append(room)
		row_rooms.append(room)
	rows.append(row_rooms)
	return row_rooms


func get_room(room_id: int) -> MapRoom:
	return rooms[room_id] if room_id >= 0 and room_id < rooms.size() else null


func get_row(row_index: int) -> Array[MapRoom]:
	var result: Array[MapRoom] = []
	if row_index >= 0 and row_index < rows.size():
		result.assign(rows[row_index])
	return result


func row_count() -> int:
	return rows.size()


## Rows before the exit room (the "5 to 7 rooms deep" part of a floor).
func depth() -> int:
	return rows.size() - 1


func exit_room() -> MapRoom:
	return rooms.back() if not rooms.is_empty() else null


## Ids of the rooms you can pick from the floor's start.
func start_ids() -> Array[int]:
	var result: Array[int] = []
	for room: MapRoom in get_row(0):
		result.append(room.id)
	return result


## Ids reachable next from `room_id`, or the start rooms for -1.
func next_ids(room_id: int) -> Array[int]:
	if room_id < 0:
		return start_ids()
	var room: MapRoom = get_room(room_id)
	var result: Array[int] = []
	if room != null:
		result.assign(room.next)
	return result
