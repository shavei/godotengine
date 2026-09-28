extends GutTest
## Local playtest metrics (docs/GDD.md Section 17): MetricsLog records, the Metrics
## autoload's opt-in and session file, and MetricsReport's prototype gate numbers.

const TEST_DIR: String = "user://test_metrics"
const TEST_SETTINGS: String = "user://test_metrics_settings.cfg"

var _enabled: bool
var _dir: String
var _settings: String
var _original_profile: ProfileState


func before_each() -> void:
	_enabled = Metrics.enabled
	_dir = Metrics.metrics_dir
	_settings = Metrics.settings_path
	_original_profile = GameState.profile
	Metrics.metrics_dir = TEST_DIR
	Metrics.settings_path = TEST_SETTINGS
	Metrics.enabled = false
	Metrics.reset_session()
	_clear_dir()
	GameState.new_profile()


func after_each() -> void:
	Metrics.reset_session()
	Metrics.enabled = _enabled
	Metrics.metrics_dir = _dir
	Metrics.settings_path = _settings
	GameState.profile = _original_profile
	_clear_dir()
	if FileAccess.file_exists(TEST_SETTINGS):
		DirAccess.remove_absolute(TEST_SETTINGS)


func _clear_dir() -> void:
	if not DirAccess.dir_exists_absolute(TEST_DIR):
		return
	for file_name: String in DirAccess.get_files_at(TEST_DIR):
		DirAccess.remove_absolute(TEST_DIR.path_join(file_name))


func _choice(action: String, seconds: float, first_gift: bool = false, kept: StringName = &"") -> Dictionary:
	return MetricsLog.choice_record(action, &"fire", 1, seconds, 1, &"", kept, first_gift)


func _session(records: Array[Dictionary], kind: String = MetricsLog.CHOICE) -> MetricsLog:
	var session: MetricsLog = MetricsLog.create("2026-09-28T10:00:00", "0.0.1")
	var t: float = 0.0
	for record: Dictionary in records:
		t += 30.0
		session.add(kind, record, t)
	return session


# --- MetricsLog ---------------------------------------------------------------

func test_choice_record_has_what_gdd_17_asks_for() -> void:
	var record: Dictionary = MetricsLog.choice_record(MetricsLog.GIVE, &"growth", 1, 12.345, 4, &"farmer")
	assert_eq(record, {"action": "give", "power": "growth", "level": 1, "seconds": 12.3, "run": 4, "villager": "farmer"})


func test_choice_record_names_the_other_power() -> void:
	var replace: Dictionary = MetricsLog.choice_record(MetricsLog.REPLACE, &"fire", 1, 3.0, 2, &"", &"stone")
	assert_eq(replace["let_go"], "stone")
	var room: Dictionary = MetricsLog.choice_record(MetricsLog.GIVE_KEPT, &"stone", 3, 3.0, 2, &"guard", &"fire")
	assert_eq(room["kept"], "fire", "the new power that took the slot")
	assert_false(room.has("first_gift"))
	assert_true(MetricsLog.choice_record(MetricsLog.GIVE, &"fire", 1, 1.0, 1, &"farmer", &"", true)["first_gift"])


func test_run_record_for_a_fall_names_the_cause_and_route() -> void:
	var summary: RunSummary = RunSummary.new()
	summary.region_id = &"mossy_hollow"
	summary.elapsed = 412.26
	summary.floor_reached = 2
	summary.rooms_cleared = 5
	summary.route = ["1:combat", "1:rest", "2:elite"] as Array[String]
	summary.death_cause = "tusk_boar"
	summary.level_after = 3
	var record: Dictionary = MetricsLog.run_record(summary, 6)
	assert_eq(record["region"], "mossy_hollow")
	assert_eq(record["seconds"], 412.3)
	assert_eq(record["result"], "fell")
	assert_eq(record["cause"], "tusk_boar")
	assert_eq(record["route"], ["1:combat", "1:rest", "2:elite"])
	assert_eq(record["floor"], 2)
	assert_eq(record["run"], 6)
	assert_false(record.has("offer"))


func test_run_record_for_a_clear_has_the_offer_and_no_cause() -> void:
	var summary: RunSummary = RunSummary.new()
	summary.success = true
	summary.power_offer = [&"fire", &"stone"] as Array[StringName]
	var record: Dictionary = MetricsLog.run_record(summary, 1)
	assert_eq(record["result"], "cleared")
	assert_false(record.has("cause"))
	assert_eq(record["offer"], ["fire", "stone"])


func test_events_keep_kind_and_time_and_survive_a_round_trip() -> void:
	var session: MetricsLog = MetricsLog.create("2026-09-28T10:00:00", "0.0.1")
	session.add(MetricsLog.RANK_UP, MetricsLog.rank_up_record(&"farmer", &"growth", TrainingSystem.ADEPT, 3), 61.234)
	session.add(MetricsLog.RENOWN, MetricsLog.renown_record(2, 4, 7), 90.0)
	assert_eq(session.events[0]["kind"], "rank_up")
	assert_eq(session.events[0]["t"], 61.2)
	assert_eq(session.events[0]["rank"], "adept")
	var copy: MetricsLog = MetricsLog.from_dict(JSON.parse_string(JSON.stringify(session.to_dict())))
	assert_eq(copy.started, "2026-09-28T10:00:00")
	assert_eq(copy.version, "0.0.1")
	assert_eq(copy.events.size(), 2)
	assert_eq(copy.of_kind(MetricsLog.RENOWN).size(), 1)


# --- MetricsReport ------------------------------------------------------------

func test_report_counts_the_share_of_powers_given() -> void:
	var records: Array[Dictionary] = [
		_choice(MetricsLog.GIVE, 12.0, true),
		_choice(MetricsLog.GIVE, 20.0),
		_choice(MetricsLog.KEEP, 30.0),
		_choice(MetricsLog.MERGE, 5.0),
		_choice(MetricsLog.GIVE, 40.0),
		_choice(MetricsLog.GIVE_KEPT, 8.0),
	]
	var summary: Dictionary = MetricsReport.summarize([_session(records)] as Array[MetricsLog])
	assert_eq(summary["choices"], 4, "the forced first gift is not a choice; a later Shrine gift is counted apart")
	assert_eq(summary["given_share"], 0.5)
	assert_eq(summary["gave_kept"], 1)
	assert_eq(summary["median_choice_seconds"], 25.0)
	assert_true(MetricsReport.given_share_ok(summary))
	assert_true(MetricsReport.choice_time_ok(summary))


func test_giving_a_kept_power_to_make_room_counts_as_keeping_the_new_one() -> void:
	var records: Array[Dictionary] = [_choice(MetricsLog.GIVE_KEPT, 15.0, false, &"frost")]
	var summary: Dictionary = MetricsReport.summarize([_session(records)] as Array[MetricsLog])
	assert_eq(summary["choices"], 1)
	assert_eq(summary["actions"][MetricsLog.KEEP], 1)
	assert_eq(summary["given_share"], 0.0)
	assert_false(MetricsReport.given_share_ok(summary))


func test_report_counts_runs_and_causes_of_death() -> void:
	var runs: Array[Dictionary] = [
		{"result": "fell", "cause": "tusk_boar", "seconds": 300.0},
		{"result": "fell", "cause": "tusk_boar", "seconds": 200.0},
		{"result": "cleared", "seconds": 800.0},
	]
	var summary: Dictionary = MetricsReport.summarize([_session(runs, MetricsLog.RUN)] as Array[MetricsLog])
	assert_eq(summary["runs"], 3)
	assert_eq(summary["cleared"], 1)
	assert_eq(summary["fell"], 2)
	assert_eq(summary["causes"], {"tusk_boar": 2})
	assert_eq(summary["median_run_seconds"], 300.0)
	assert_string_contains(MetricsReport.text(summary), "Falls by: tusk_boar 2")


func test_report_with_no_data_says_n_a() -> void:
	var summary: Dictionary = MetricsReport.summarize([] as Array[MetricsLog])
	assert_null(MetricsReport.given_share_ok(summary))
	assert_null(MetricsReport.choice_time_ok(summary))
	assert_string_contains(MetricsReport.text(summary), "Powers given: n/a")


func test_median() -> void:
	assert_eq(MetricsReport.median([] as Array[float]), -1.0)
	assert_eq(MetricsReport.median([9.0, 1.0, 5.0] as Array[float]), 5.0)
	assert_eq(MetricsReport.median([4.0, 1.0, 2.0, 10.0] as Array[float]), 3.0)


func test_out_of_range_numbers_are_flagged() -> void:
	var records: Array[Dictionary] = [_choice(MetricsLog.KEEP, 3.0), _choice(MetricsLog.KEEP, 4.0)]
	var summary: Dictionary = MetricsReport.summarize([_session(records)] as Array[MetricsLog])
	assert_false(MetricsReport.choice_time_ok(summary), "under 10 s: the Choice is too easy")
	assert_string_contains(MetricsReport.text(summary), "OUT OF RANGE")


# --- Metrics autoload -----------------------------------------------------------

func test_nothing_is_logged_until_the_player_opts_in() -> void:
	EventBus.choice_made.emit(0, _choice(MetricsLog.KEEP, 10.0))
	assert_null(Metrics.session)
	assert_false(DirAccess.dir_exists_absolute(TEST_DIR) and DirAccess.get_files_at(TEST_DIR).size() > 0)


func test_opting_in_is_saved() -> void:
	assert_false(Metrics.saved_enabled())
	assert_eq(Metrics.set_enabled(true), OK)
	assert_true(Metrics.enabled)
	assert_true(Metrics.saved_enabled())
	Metrics.set_enabled(false)
	assert_false(Metrics.saved_enabled())


func test_each_event_rewrites_the_session_file() -> void:
	Metrics.enabled = true
	EventBus.choice_made.emit(0, _choice(MetricsLog.KEEP, 10.0))
	assert_not_null(Metrics.session)
	assert_true(Metrics.session_path.begins_with(TEST_DIR.path_join("session_")))
	assert_false(Metrics.session_path.get_file().contains(":"), "no colons in file names (Windows)")
	EventBus.renown_changed.emit(4, 2)
	var sessions: Array[MetricsLog] = MetricsReport.read_dir(TEST_DIR)
	assert_eq(sessions.size(), 1)
	assert_eq(sessions[0].events.size(), 2)
	assert_eq(sessions[0].events[0]["kind"], "choice")
	assert_eq(int(sessions[0].events[0]["player"]), 0)
	assert_eq(sessions[0].events[1]["kind"], "renown")
	assert_eq(int(sessions[0].events[1]["level"]), 2)


func test_a_second_session_in_the_same_second_gets_its_own_file() -> void:
	Metrics.enabled = true
	Metrics.log_event(MetricsLog.RENOWN, {})
	var first: String = Metrics.session_path
	Metrics.reset_session()
	Metrics.log_event(MetricsLog.RENOWN, {})
	assert_ne(Metrics.session_path, first)
	assert_eq(DirAccess.get_files_at(TEST_DIR).size(), 2)


func test_rank_ups_and_lessons_name_the_villager() -> void:
	Metrics.enabled = true
	var farmer: VillagerState = GameState.profile.village.find(&"farmer")
	farmer.power_id = &"growth"
	EventBus.villager_ranked_up.emit(GameState.profile.village.index_of(&"farmer"), TrainingSystem.MASTER)
	EventBus.technique_learned.emit(0, &"regrowth")
	var rank_up: Dictionary = Metrics.session.of_kind(MetricsLog.RANK_UP)[0]
	assert_eq(rank_up["villager"], "farmer")
	assert_eq(rank_up["power"], "growth")
	assert_eq(rank_up["rank"], "master")
	var lesson: Dictionary = Metrics.session.of_kind(MetricsLog.TECHNIQUE)[0]
	assert_eq(lesson["technique"], "regrowth")
	assert_eq(lesson["teacher"], "farmer")


func test_run_results_are_logged() -> void:
	Metrics.enabled = true
	var summary: RunSummary = RunSummary.new()
	summary.death_cause = "thorn_archer_arrow"
	EventBus.run_summarized.emit(summary)
	var run: Dictionary = Metrics.session.of_kind(MetricsLog.RUN)[0]
	assert_eq(run["result"], "fell")
	assert_eq(run["cause"], "thorn_archer_arrow")
