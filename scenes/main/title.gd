extends Control
## Placeholder title screen. The full menu (Seasons, Settings, Codex, ...) comes later.
## For now it goes to the village (runs start at its gate), continues a saved run, or
## opens the M1 combat test room, wave room or tuning room. A saved run (quit or crash
## mid-run) shows Continue run; the profile line says when a power waits at the Shrine.
## New game (second press to confirm) starts a fresh profile, first gift tutorial included.
## Controls stay (they are per machine).

const RUN_ROOM_SCENE: String = "res://scenes/run/room.tscn"
const VILLAGE_SCENE: String = "res://scenes/village/village.tscn"
const TEST_ROOM_SCENE: String = "res://scenes/run/test_room.tscn"
const WAVE_ROOM_SCENE: String = "res://scenes/run/wave_room.tscn"
const TUNING_ROOM_SCENE: String = "res://scenes/run/tuning_room.tscn"
const CONTROLS_SCENE: String = "res://scenes/ui/controls_menu.tscn"
const NEW_GAME_TEXT: String = "New game"
const NEW_GAME_CONFIRM: String = "Sure? Your progress is lost"

## The New game button asked "Sure?" and waits for a second press.
var _new_game_armed: bool = false


func _ready() -> void:
	%Version.text = "v%s  |  Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.1"),
		Engine.get_version_info()["string"],
	]
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%VillageButton.pressed.connect(_on_village_pressed)
	%NewGameButton.pressed.connect(_on_new_game_pressed)
	%NewGameButton.focus_exited.connect(_disarm_new_game)
	%PlayButton.pressed.connect(_on_play_pressed)
	%WaveButton.pressed.connect(_on_wave_pressed)
	%TuningButton.pressed.connect(_on_tuning_pressed)
	%ControlsButton.pressed.connect(_on_controls_pressed)
	%ContinueButton.visible = GameState.has_saved_run()
	if %ContinueButton.visible:
		%ContinueButton.grab_focus()
	else:
		%VillageButton.grab_focus()
	refresh_profile()


## One line about the hero: level, XP and banked coins.
func refresh_profile() -> void:
	var hero: HeroState = GameState.hero_state(GameState.LOCAL_PLAYER_ID)
	var balance: BalanceData = ContentDB.get_item(&"balance", &"default") as BalanceData
	var next_xp: int = ProgressionSystem.xp_to_next(hero, balance) if balance != null else 0
	var xp_text: String = "  |  %d / %d XP" % [hero.xp, next_xp] if next_xp > 0 else ""
	%Profile.text = "Level %d%s  |  %d coins banked  |  Runs %d" % [hero.level, xp_text, hero.bank.amount(Wallet.COINS), GameState.profile.run_count]
	if not hero.power_offer.is_empty():
		%Profile.text += "\nA power waits at the Shrine."


func _on_continue_pressed() -> void:
	if GameState.load_saved_run():
		SceneRouter.go(RUN_ROOM_SCENE)
	else:
		%ContinueButton.hide()
		%VillageButton.grab_focus()


## First press asks, the second wipes the profile and any saved run.
func _on_new_game_pressed() -> void:
	if not _new_game_armed:
		_new_game_armed = true
		%NewGameButton.text = NEW_GAME_CONFIRM
		return
	start_new_game()
	_disarm_new_game()


## A fresh profile: level 1, no powers, the starting villagers, the first gift ahead.
func start_new_game() -> void:
	GameState.end_run()
	GameState.new_profile()
	GameState.save_profile()
	%ContinueButton.hide()
	%VillageButton.grab_focus()
	refresh_profile()


func _disarm_new_game() -> void:
	_new_game_armed = false
	%NewGameButton.text = NEW_GAME_TEXT


func _on_village_pressed() -> void:
	SceneRouter.go(VILLAGE_SCENE)


func _on_play_pressed() -> void:
	SceneRouter.go(TEST_ROOM_SCENE)


func _on_wave_pressed() -> void:
	SceneRouter.go(WAVE_ROOM_SCENE)


func _on_tuning_pressed() -> void:
	SceneRouter.go(TUNING_ROOM_SCENE)


func _on_controls_pressed() -> void:
	SceneRouter.go(CONTROLS_SCENE)
