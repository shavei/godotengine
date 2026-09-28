extends Control
## Placeholder title screen. Real menu (Continue, New Game, Seasons, ...) comes later.
## For now it starts or continues a Mossy Hollow run, or opens the M1 combat test room,
## wave room or tuning room. A saved run (quit or crash mid-run) shows Continue run, and
## a boss's power offer not settled yet shows "A power is waiting" (the Choice screen).

const RUN_ROOM_SCENE: String = "res://scenes/run/room.tscn"
## Until the village gate exists (M4), runs start in the first region.
const START_REGION: StringName = &"mossy_hollow"
const TEST_ROOM_SCENE: String = "res://scenes/run/test_room.tscn"
const WAVE_ROOM_SCENE: String = "res://scenes/run/wave_room.tscn"
const TUNING_ROOM_SCENE: String = "res://scenes/run/tuning_room.tscn"
const CONTROLS_SCENE: String = "res://scenes/ui/controls_menu.tscn"
const CHOICE_SCENE: String = "res://scenes/ui/choice_screen.tscn"


func _ready() -> void:
	%Version.text = "v%s  |  Godot %s" % [
		ProjectSettings.get_setting("application/config/version", "0.0.1"),
		Engine.get_version_info()["string"],
	]
	%ClaimButton.pressed.connect(_on_claim_pressed)
	%ContinueButton.pressed.connect(_on_continue_pressed)
	%RunButton.pressed.connect(_on_run_pressed)
	%PlayButton.pressed.connect(_on_play_pressed)
	%WaveButton.pressed.connect(_on_wave_pressed)
	%TuningButton.pressed.connect(_on_tuning_pressed)
	%ControlsButton.pressed.connect(_on_controls_pressed)
	%ContinueButton.visible = GameState.has_saved_run()
	%RunButton.text = "Start a new run" if %ContinueButton.visible else "Start a run"
	%ClaimButton.visible = not GameState.hero_state(GameState.LOCAL_PLAYER_ID).power_offer.is_empty()
	if %ClaimButton.visible:
		%ClaimButton.grab_focus()
	elif %ContinueButton.visible:
		%ContinueButton.grab_focus()
	else:
		%RunButton.grab_focus()
	refresh_profile()


## One line about the hero: level, XP and banked coins.
func refresh_profile() -> void:
	var hero: HeroState = GameState.hero_state(GameState.LOCAL_PLAYER_ID)
	var balance: BalanceData = ContentDB.get_item(&"balance", &"default") as BalanceData
	var next_xp: int = ProgressionSystem.xp_to_next(hero, balance) if balance != null else 0
	var xp_text: String = "  |  %d / %d XP" % [hero.xp, next_xp] if next_xp > 0 else ""
	%Profile.text = "Level %d%s  |  %d coins banked  |  Runs %d" % [hero.level, xp_text, hero.bank.amount(Wallet.COINS), GameState.profile.run_count]


func _on_claim_pressed() -> void:
	SceneRouter.go(CHOICE_SCENE, {"player_id": GameState.LOCAL_PLAYER_ID})


func _on_continue_pressed() -> void:
	if GameState.load_saved_run():
		SceneRouter.go(RUN_ROOM_SCENE)
	else:
		%ContinueButton.hide()
		%RunButton.grab_focus()


func _on_run_pressed() -> void:
	var region: RegionData = ContentDB.get_item(&"regions", START_REGION) as RegionData
	var seed_value: int = randi()
	# A new run replaces any saved one.
	SaveManager.delete_run(GameState.slot)
	GameState.run = RunState.start(region, seed_value)
	EventBus.run_started.emit(region.id, seed_value)
	SceneRouter.go(RUN_ROOM_SCENE)


func _on_play_pressed() -> void:
	SceneRouter.go(TEST_ROOM_SCENE)


func _on_wave_pressed() -> void:
	SceneRouter.go(WAVE_ROOM_SCENE)


func _on_tuning_pressed() -> void:
	SceneRouter.go(TUNING_ROOM_SCENE)


func _on_controls_pressed() -> void:
	SceneRouter.go(CONTROLS_SCENE)
