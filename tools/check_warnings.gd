extends SceneTree
## Fails if any project script (addons excluded) has a GDScript warning.
## The editor lists warnings in the debugger, but headless runs do not print them.
## Run from the repo root: godot --headless -s tools/check_warnings.gd
##
## How: Godot reads warning levels only at startup, so this writes a temporary
## override.cfg that turns every "warn" level warning into an error, runs itself
## again as a child process to compile each script, then deletes the file.

const WARNING_PREFIX: String = "debug/gdscript/warnings/"
const OVERRIDE_PATH: String = "res://override.cfg"
## Set in override.cfg so the child process knows it should do the check.
const CHILD_MARKER: String = "application/config/check_warnings_child"
const WARN: int = 1
const ERROR: int = 2
const SKIP_DIRS: Array[String] = ["res://addons", "res://.godot"]


func _initialize() -> void:
	if ProjectSettings.get_setting(CHILD_MARKER, false):
		quit(_check_scripts())
	else:
		quit(_run_child())


## Parent: write override.cfg, run the child, clean up, pass on its exit code.
func _run_child() -> int:
	if FileAccess.file_exists(OVERRIDE_PATH):
		printerr("check_warnings: override.cfg already exists, not touching it")
		return 1
	var cfg: ConfigFile = ConfigFile.new()
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		var value: Variant = ProjectSettings.get_setting(key)
		if key.begins_with(WARNING_PREFIX) and value is int and value == WARN:
			var parts: PackedStringArray = key.split("/", false, 1)
			cfg.set_value(parts[0], parts[1], ERROR)
	var marker: PackedStringArray = CHILD_MARKER.split("/", false, 1)
	cfg.set_value(marker[0], marker[1], true)
	cfg.save(OVERRIDE_PATH)
	var output: Array = []
	var script_path: String = (get_script() as Script).resource_path
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "-s", script_path], output, true)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OVERRIDE_PATH))
	for chunk: String in output:
		print(chunk)
	return code


## Child: compile every script with warnings raised to errors.
func _check_scripts() -> int:
	var scripts: Array[String] = []
	_collect("res://", scripts)
	var failed: Array[String] = []
	for path: String in scripts:
		# Bypass the cache so each script compiles with the raised warning levels.
		var script: Script = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if script == null or not script.can_instantiate():
			failed.append(path)
	if failed.is_empty():
		print("check_warnings: %d scripts, no warnings" % scripts.size())
		return 0
	print("check_warnings: warnings in %d script(s), see the Parse Errors above: %s" % [failed.size(), ", ".join(failed)])
	return 1


func _collect(dir_path: String, out: Array[String]) -> void:
	if SKIP_DIRS.has(dir_path.trim_suffix("/")):
		return
	var own_path: String = (get_script() as Script).resource_path
	for file: String in DirAccess.get_files_at(dir_path):
		# Reloading the running script would hang.
		if file.ends_with(".gd") and dir_path.path_join(file) != own_path:
			out.append(dir_path.path_join(file))
	for sub: String in DirAccess.get_directories_at(dir_path):
		_collect(dir_path.path_join(sub), out)
