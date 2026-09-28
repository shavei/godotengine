extends SceneTree
## Prints the prototype gate's numbers from playtest metrics files (MetricsReport).
## Run from the repo root: godot --headless -s tools/metrics_report.gd -- <folder>
## Put every tester's session_*.json files in one folder. With no folder it reads this
## computer's own log (user://metrics).


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = args[0] if not args.is_empty() else "user://metrics"
	if not DirAccess.dir_exists_absolute(dir):
		printerr("metrics_report: no folder at %s" % dir)
		quit(1)
		return
	var sessions: Array[MetricsLog] = MetricsReport.read_dir(dir)
	print("Metrics from %s" % ProjectSettings.globalize_path(dir))
	print(MetricsReport.text(MetricsReport.summarize(sessions)))
	quit(0)
