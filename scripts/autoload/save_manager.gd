extends Node
## Reads and writes save slots as versioned JSON, keeping a .bak of the previous save.
## Migrations are added here as the save format changes (docs/ARCHITECTURE.md Section 10).

const SAVE_VERSION: int = 1

var save_dir: String = "user://saves"


func slot_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.json" % slot)


func backup_path(slot: int) -> String:
	return save_dir.path_join("slot_%d.bak" % slot)


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(slot_path(slot))


## Writes `data` to the slot. The previous save (if any) is kept as a backup.
func save_data(slot: int, data: Dictionary) -> Error:
	var err: Error = DirAccess.make_dir_recursive_absolute(save_dir)
	if err != OK:
		return err
	var path: String = slot_path(slot)
	if FileAccess.file_exists(path):
		err = DirAccess.copy_absolute(path, backup_path(slot))
		if err != OK:
			return err
	var payload: Dictionary = data.duplicate(true)
	payload["version"] = SAVE_VERSION
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	EventBus.game_saved.emit(slot)
	return OK


## Returns the slot's data, falling back to the backup if the main file is unreadable.
## Returns an empty Dictionary if neither can be read.
func load_data(slot: int) -> Dictionary:
	var data: Dictionary = _read_json(slot_path(slot))
	if data.is_empty():
		data = _read_json(backup_path(slot))
	if data.is_empty():
		return {}
	data = _migrate(data)
	EventBus.game_loaded.emit(slot)
	return data


func delete_slot(slot: int) -> void:
	for path: String in [slot_path(slot), backup_path(slot)]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var json: JSON = JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) == OK and json.data is Dictionary:
		return json.data
	push_warning("SaveManager: could not parse %s (line %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
	return {}


func _migrate(data: Dictionary) -> Dictionary:
	# No migrations yet. Add `if version < N:` steps here as the format evolves.
	data["version"] = SAVE_VERSION
	return data
