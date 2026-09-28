class_name MetricsReport
extends RefCounted
## Sums up playtest sessions (MetricsLog) into the prototype gate's numbers
## (docs/ROADMAP.md, M5): the share of new powers given away and the median time spent on
## a Choice, plus runs, causes of death, rank-ups and Techniques. The forced first gift is
## left out of the Choice numbers (it is not a choice); a kept power given away to make
## room counts as keeping the new power. tools/metrics_report.gd prints it.

## The gate's targets.
const GIVEN_SHARE_MIN: float = 0.4
const GIVEN_SHARE_MAX: float = 0.6
const CHOICE_SECONDS_MIN: float = 10.0
const CHOICE_SECONDS_MAX: float = 40.0
## Actions that settle a new power (a kept power given later is counted on its own).
const SETTLING: Array[String] = [MetricsLog.KEEP, MetricsLog.MERGE, MetricsLog.GIVE, MetricsLog.REPLACE, MetricsLog.LEAVE]


static func summarize(sessions: Array[MetricsLog]) -> Dictionary:
	var actions: Dictionary = {}
	var choice_seconds: Array[float] = []
	var run_seconds: Array[float] = []
	var causes: Dictionary = {}
	var cleared: int = 0
	var fell: int = 0
	var play_seconds: float = 0.0
	var adepts: int = 0
	var masters: int = 0
	var techniques: int = 0
	var gave_kept: int = 0
	for session: MetricsLog in sessions:
		if not session.events.is_empty():
			play_seconds += float(session.events.back().get("t", 0.0))
		for event: Dictionary in session.events:
			match str(event.get("kind", "")):
				MetricsLog.CHOICE:
					var action: String = str(event.get("action", ""))
					if action == MetricsLog.GIVE_KEPT:
						gave_kept += 1
						if event.has("kept"):
							# Made room: the new power was kept.
							actions[MetricsLog.KEEP] = int(actions.get(MetricsLog.KEEP, 0)) + 1
							choice_seconds.append(float(event.get("seconds", 0.0)))
					elif SETTLING.has(action) and not bool(event.get("first_gift", false)):
						actions[action] = int(actions.get(action, 0)) + 1
						choice_seconds.append(float(event.get("seconds", 0.0)))
				MetricsLog.RUN:
					run_seconds.append(float(event.get("seconds", 0.0)))
					if str(event.get("result", "")) == "cleared":
						cleared += 1
					else:
						fell += 1
						var cause: String = str(event.get("cause", "unknown"))
						causes[cause] = int(causes.get(cause, 0)) + 1
				MetricsLog.RANK_UP:
					if str(event.get("rank", "")) == "master":
						masters += 1
					else:
						adepts += 1
				MetricsLog.TECHNIQUE:
					techniques += 1
	var settled: int = 0
	for action: String in actions:
		settled += int(actions[action])
	var given: int = int(actions.get(MetricsLog.GIVE, 0))
	return {
		"sessions": sessions.size(),
		"play_seconds": play_seconds,
		"choices": settled,
		"actions": actions,
		"given_share": float(given) / settled if settled > 0 else -1.0,
		"gave_kept": gave_kept,
		"median_choice_seconds": median(choice_seconds),
		"runs": run_seconds.size(),
		"cleared": cleared,
		"fell": fell,
		"median_run_seconds": median(run_seconds),
		"causes": causes,
		"adepts": adepts,
		"masters": masters,
		"techniques": techniques,
	}


## The middle value (the mean of the two middle values for an even count), or -1 if empty.
static func median(values: Array[float]) -> float:
	if values.is_empty():
		return -1.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var middle: int = floori(sorted.size() / 2.0)
	if sorted.size() % 2 == 1:
		return sorted[middle]
	return (sorted[middle - 1] + sorted[middle]) * 0.5


## True / false against the gate's range, or null while there is no data.
static func given_share_ok(summary: Dictionary) -> Variant:
	var share: float = float(summary.get("given_share", -1.0))
	if share < 0.0:
		return null
	return share >= GIVEN_SHARE_MIN and share <= GIVEN_SHARE_MAX


static func choice_time_ok(summary: Dictionary) -> Variant:
	var seconds: float = float(summary.get("median_choice_seconds", -1.0))
	if seconds < 0.0:
		return null
	return seconds >= CHOICE_SECONDS_MIN and seconds <= CHOICE_SECONDS_MAX


## A few plain lines for the Output panel or a terminal.
static func text(summary: Dictionary) -> String:
	var lines: PackedStringArray = []
	lines.append("Sessions: %d, played %s" % [int(summary.get("sessions", 0)), _time(float(summary.get("play_seconds", 0.0)))])
	var share: float = float(summary.get("given_share", -1.0))
	var actions: Dictionary = summary.get("actions", {})
	var parts: PackedStringArray = []
	for action: String in SETTLING:
		parts.append("%s %d" % [action, int(actions.get(action, 0))])
	lines.append("Choices: %d (%s); kept powers given later: %d" % [
		int(summary.get("choices", 0)), ", ".join(parts), int(summary.get("gave_kept", 0))])
	lines.append("Powers given: %s (gate: 40%% to 60%%) %s" % [
		"n/a" if share < 0.0 else "%d%%" % roundi(share * 100.0), _mark(given_share_ok(summary))])
	var choice_time: float = float(summary.get("median_choice_seconds", -1.0))
	lines.append("Median Choice time: %s (gate: 10 to 40 s) %s" % [
		"n/a" if choice_time < 0.0 else "%.1f s" % choice_time, _mark(choice_time_ok(summary))])
	var run_time: float = float(summary.get("median_run_seconds", -1.0))
	lines.append("Runs: %d (cleared %d, fell %d), median length %s" % [
		int(summary.get("runs", 0)), int(summary.get("cleared", 0)), int(summary.get("fell", 0)),
		"n/a" if run_time < 0.0 else _time(run_time)])
	var causes: Dictionary = summary.get("causes", {})
	if not causes.is_empty():
		var names: Array = causes.keys()
		names.sort_custom(func(a: Variant, b: Variant) -> bool: return int(causes[a]) > int(causes[b]))
		var cause_parts: PackedStringArray = []
		for cause: Variant in names:
			cause_parts.append("%s %d" % [cause, int(causes[cause])])
		lines.append("Falls by: %s" % ", ".join(cause_parts))
	lines.append("Rank-ups: Adept %d, Master %d; Techniques learned: %d" % [
		int(summary.get("adepts", 0)), int(summary.get("masters", 0)), int(summary.get("techniques", 0))])
	return "\n".join(lines)


static func _mark(ok: Variant) -> String:
	if ok == null:
		return ""
	return "OK" if ok else "OUT OF RANGE"


static func _time(seconds: float) -> String:
	var whole: int = floori(seconds)
	return "%d:%02d" % [floori(whole / 60.0), whole % 60]


## Every session file (*.json) in `dir`, oldest first. Unreadable files are skipped.
static func read_dir(dir: String) -> Array[MetricsLog]:
	var sessions: Array[MetricsLog] = []
	if not DirAccess.dir_exists_absolute(dir):
		return sessions
	var files: PackedStringArray = DirAccess.get_files_at(dir)
	files.sort()
	for file_name: String in files:
		if not file_name.ends_with(".json"):
			continue
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(file_name)))
		if data is Dictionary:
			sessions.append(MetricsLog.from_dict(data))
	return sessions
