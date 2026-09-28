class_name MetricsLog
extends RefCounted
## One play session's local metrics (docs/GDD.md Section 17): every Choice, run, rank-up,
## Technique and Renown level, in order, with the seconds since the session began. The
## Metrics autoload fills it from EventBus signals and writes it as one JSON file per
## session (opt-in). Fusions, neighbor bonuses and raids join when they exist (M6).
## MetricsReport reads the files back for the prototype gate numbers.

const FORMAT: int = 1

const CHOICE: String = "choice"
const RUN: String = "run"
const RANK_UP: String = "rank_up"
const TECHNIQUE: String = "technique"
const RENOWN: String = "renown"

## Choice actions. KEEP, MERGE, GIVE, REPLACE and LEAVE settle a new power; GIVE_KEPT
## gives a power the hero kept (at the Shrine, or to make room: then `kept` is the new
## power taking its slot).
const KEEP: String = "keep"
const MERGE: String = "merge"
const GIVE: String = "give"
const GIVE_KEPT: String = "give_kept"
const REPLACE: String = "replace"
const LEAVE: String = "leave"

## When the session began, as "YYYY-MM-DDTHH:MM:SS" (local time).
var started: String = ""
## The game's version (project setting application/config/version).
var version: String = ""
## Each event: {"kind", "t" (seconds since the session began), ...its record}.
var events: Array[Dictionary] = []


static func create(started_at: String, game_version: String) -> MetricsLog:
	var session: MetricsLog = MetricsLog.new()
	session.started = started_at
	session.version = game_version
	return session


## Adds an event and returns it.
func add(kind: String, record: Dictionary, seconds: float) -> Dictionary:
	var event: Dictionary = record.duplicate(true)
	event["kind"] = kind
	event["t"] = snappedf(seconds, 0.1)
	events.append(event)
	return event


func of_kind(kind: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event: Dictionary in events:
		if event.get("kind", "") == kind:
			result.append(event)
	return result


## One Choice. `level` is the power's level (a merge: the new level; a kept power given:
## its level). `seconds` is how long the power waited on screen before the Choice.
static func choice_record(action: String, power_id: StringName, level: int, seconds: float,
		run_number: int, villager_id: StringName = &"", other_power: StringName = &"", first_gift: bool = false) -> Dictionary:
	var record: Dictionary = {
		"action": action,
		"power": String(power_id),
		"level": level,
		"seconds": snappedf(maxf(seconds, 0.0), 0.1),
		"run": run_number,
	}
	if villager_id != &"":
		record["villager"] = String(villager_id)
	if other_power != &"":
		# REPLACE: the kept power let go. GIVE_KEPT: the new power taking its slot.
		record["let_go" if action == REPLACE else "kept"] = String(other_power)
	if first_gift:
		record["first_gift"] = true
	return record


## One finished run: region, duration, result, cause of death and room path.
static func run_record(summary: RunSummary, run_number: int) -> Dictionary:
	var record: Dictionary = {
		"region": String(summary.region_id),
		"seconds": snappedf(summary.elapsed, 0.1),
		"result": "cleared" if summary.success else "fell",
		"floor": summary.floor_reached,
		"rooms_cleared": summary.rooms_cleared,
		"route": summary.route.duplicate(),
		"level": summary.level_after,
		"run": run_number,
	}
	if not summary.success:
		record["cause"] = summary.death_cause if not summary.death_cause.is_empty() else "unknown"
	if not summary.power_offer.is_empty():
		record["offer"] = Array(summary.power_offer).map(func(id: StringName) -> String: return String(id))
	return record


static func rank_up_record(villager_id: StringName, power_id: StringName, rank: int, run_number: int) -> Dictionary:
	return {"villager": String(villager_id), "power": String(power_id),
			"rank": TrainingSystem.rank_name(rank).to_lower(), "run": run_number}


static func technique_record(technique_id: StringName, teacher_id: StringName, run_number: int) -> Dictionary:
	return {"technique": String(technique_id), "teacher": String(teacher_id), "run": run_number}


static func renown_record(renown_level: int, renown_points: int, run_number: int) -> Dictionary:
	return {"level": renown_level, "points": renown_points, "run": run_number}


func to_dict() -> Dictionary:
	return {"format": FORMAT, "started": started, "version": version, "events": events.duplicate(true)}


static func from_dict(data: Dictionary) -> MetricsLog:
	var session: MetricsLog = MetricsLog.create(str(data.get("started", "")), str(data.get("version", "")))
	for event: Variant in data.get("events", []):
		if event is Dictionary:
			session.events.append(event)
	return session
