extends Node
## Loads every content Resource under res://data/ at boot and indexes it by folder and id.
## Content Resources expose an `id: StringName` property (see docs/ARCHITECTURE.md Section 4).

const DATA_ROOT: String = "res://data"

## category (folder name, e.g. &"powers") -> { id -> Resource }
var _by_category: Dictionary = {}


func _ready() -> void:
	load_all(DATA_ROOT)


## Clears and reloads all content from `root`. Returns the number of resources loaded.
func load_all(root: String) -> int:
	_by_category.clear()
	var total: int = 0
	var dir: DirAccess = DirAccess.open(root)
	if dir == null:
		push_warning("ContentDB: data folder not found: %s" % root)
		return 0
	for category: String in dir.get_directories():
		total += _load_category(root.path_join(category), StringName(category))
	return total


func get_item(category: StringName, id: StringName) -> Resource:
	var items: Dictionary = _by_category.get(category, {})
	return items.get(id, null)


func get_all(category: StringName) -> Array[Resource]:
	var result: Array[Resource] = []
	var items: Dictionary = _by_category.get(category, {})
	for item: Resource in items.values():
		result.append(item)
	return result


func count(category: StringName) -> int:
	var items: Dictionary = _by_category.get(category, {})
	return items.size()


func _load_category(path: String, category: StringName) -> int:
	var items: Dictionary = {}
	for file_name: String in ResourceLoader.list_directory(path):
		if not file_name.ends_with(".tres"):
			continue
		var res: Resource = load(path.path_join(file_name))
		if res == null or not ("id" in res):
			push_error("ContentDB: %s/%s has no `id` property" % [path, file_name])
			continue
		var id: StringName = res.get("id")
		if items.has(id):
			push_error("ContentDB: duplicate id %s in %s" % [id, path])
			continue
		items[id] = res
	_by_category[category] = items
	return items.size()
