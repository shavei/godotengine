extends Node
## Local playtest metrics (docs/GDD.md Section 17). Off until the player turns on the
## Playtest log on the title (saved in user://settings.cfg). While it is on, every Choice,
## run, rank-up, Technique and Renown level goes into this session's MetricsLog, and the
## session's file (user://metrics/session_<date>T<time>.json) is written again after each
## one, so quitting or a crash loses nothing. Nothing leaves the computer: testers send
## the files by hand. tools/metrics_report.gd sums them up for the prototype gate.

const SECTION: String = "metrics"

## Logging is on (the player opted in).
var enabled: bool = false
var metrics_dir: String = "user://metrics"
var settings_path: String = InputBindings.SETTINGS_PATH
## This session's log, or null until the first event is logged.
var session: MetricsLog
## Where this session's file is written ("" until the first event).
var session_path: String = ""

var _start_msec: int = 0


func _ready() -> void:
	_start_msec = Time.get_ticks_msec()
	enabled = saved_enabled()
	EventBus.choice_made.connect(_on_choice_made)
	EventBus.run_summarized.connect(_on_run_summarized)
	EventBus.villager_ranked_up.connect(_on_villager_ranked_up)
	EventBus.technique_learned.connect(_on_technique_learned)
	EventBus.renown_changed.connect(_on_renown_changed)


## The saved opt-in (false if never set).
func saved_enabled() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) != OK:
		return false
	return bool(config.get_value(SECTION, "enabled", false))


## Turns logging on or off and saves the choice.
func set_enabled(value: bool) -> Error:
	enabled = value
	var config: ConfigFile = ConfigFile.new()
	config.load(settings_path)
	config.set_value(SECTION, "enabled", value)
	return config.save(settings_path)


## Seconds since the game started.
func seconds() -> float:
	return (Time.get_ticks_msec() - _start_msec) / 1000.0


## Logs one event (when enabled) and writes the session file. Returns the event, or an
## empty Dictionary when logging is off.
func log_event(kind: String, record: Dictionary) -> Dictionary:
	if not enabled:
		return {}
	if session == null:
		_begin()
	var event: Dictionary = session.add(kind, record, seconds())
	write()
	return event


## Writes this session's file.
func write() -> Error:
	if session == null:
		return ERR_DOES_NOT_EXIST
	var err: Error = DirAccess.make_dir_recursive_absolute(metrics_dir)
	if err != OK:
		return err
	var file: FileAccess = FileAccess.open(session_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(session.to_dict(), "\t"))
	file.close()
	return OK


## The folder as a path the system's file browser can open.
func folder_path() -> String:
	return ProjectSettings.globalize_path(metrics_dir)


## Opens the metrics folder in the system's file browser (made if missing).
func open_folder() -> Error:
	DirAccess.make_dir_recursive_absolute(metrics_dir)
	return OS.shell_open(folder_path())


## Forgets this session (tests); the next event starts a new file.
func reset_session() -> void:
	session = null
	session_path = ""


func _begin() -> void:
	var started: String = Time.get_datetime_string_from_system()
	session = MetricsLog.create(started, str(ProjectSettings.get_setting("application/config/version", "")))
	var stem: String = "session_%s" % started.replace(":", "-")
	session_path = metrics_dir.path_join(stem + ".json")
	var copy: int = 2
	while FileAccess.file_exists(session_path):
		session_path = metrics_dir.path_join("%s_%d.json" % [stem, copy])
		copy += 1


func _run_number() -> int:
	return GameState.profile.run_count


func _on_choice_made(player_id: int, record: Dictionary) -> void:
	var entry: Dictionary = record.duplicate()
	entry["player"] = player_id
	log_event(MetricsLog.CHOICE, entry)


func _on_run_summarized(summary: RunSummary) -> void:
	var entry: Dictionary = MetricsLog.run_record(summary, _run_number())
	entry["player"] = summary.player_id
	log_event(MetricsLog.RUN, entry)


func _on_villager_ranked_up(villager_index: int, new_rank: int) -> void:
	var villagers: Array[VillagerState] = GameState.profile.village.villagers
	if villager_index < 0 or villager_index >= villagers.size():
		return
	var villager: VillagerState = villagers[villager_index]
	log_event(MetricsLog.RANK_UP, MetricsLog.rank_up_record(villager.villager_id, villager.power_id, new_rank, _run_number()))


func _on_technique_learned(player_id: int, technique_id: StringName) -> void:
	var combo: ComboData = TechniqueSystem.teacher(GameState.combos(), technique_id)
	var entry: Dictionary = MetricsLog.technique_record(technique_id, combo.villager_id if combo != null else &"", _run_number())
	entry["player"] = player_id
	log_event(MetricsLog.TECHNIQUE, entry)


func _on_renown_changed(points: int, level: int) -> void:
	log_event(MetricsLog.RENOWN, MetricsLog.renown_record(level, points, _run_number()))
