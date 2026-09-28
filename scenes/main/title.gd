extends Control
## Placeholder title screen. Real menu (Continue, New Game, Seasons, ...) comes later.
## For now it goes to the village (runs start at its gate), continues a saved run, or
## opens the M1 combat test room, wave room or tuning room. A saved run (quit or crash
## mid-run) shows Continue run; the profile line says when a power waits at the Shrine.

const RUN_ROOM_SCENE: String = "res://scenes/run/room.tscn"
const VILLAGE_SCENE: String = "res://scenes/village/village.tscn"
const TEST_ROOM_SCENE: String = "res://scenes/run/test_room.tscn"
const WAVE_ROOM_SCENE: String = "res://scenes/run/wave_room.tscn"
const TUNING_ROOM_SCENE: String = "res://scenes/run/tuning_room.tscn"
const CONTROLS_SCENE: String = "res://scenes/ui/controls_menu.tscn"


func _ready() -> void:
	%Version.text = "v%s  |  Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.1"),
		Engine.get_version_info()["string"],
	]
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%VillageButton.pressed.connect(_on_village_pressed)
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
		%RunButton.grab_focus()


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
