class_name Village
extends Node2D
## Emberwick, the village hub (docs/GDD.md Sections 2 and 5). The hero walks between
## runs: villagers stand in front of their houses on the 6 plots and say what they do,
## the Shrine glows while a power waits and opens the Choice screen, and the gate starts
## a run (or continues a saved one). The notice board will carry raid warnings (M6).
## Every gift shows here: the villager glows in the power's color and their roof is trimmed
## with it. A villager who sells something (the Smith's weapon tiers, an infusion) opens
## their shop when talked to. Right after a gift the Choice screen comes back here with a
## "ceremony" in the router context, and the gift ceremony plays (GiftCeremony). While the
## first power must still be given (FirstGift), the Elder's words point to the Shrine.
## Once nothing waits at the Shrine, the runs' training ticks apply (TrainingSystem) and
## the village shows what they did: a VillageMoment for every villager reaching Adept or
## Master, then one for every new Renown level with the villager who moves in. The gate
## stays shut while a power waits, so every run's power is settled before the next.
## A Master teaches the hero their Technique right after (TechniqueSystem): a lesson
## moment calls the hero over to them. The Map button opens the character sheet.
## Placeholder art until M7.

const RUN_ROOM_SCENE: String = "res://scenes/run/room.tscn"
const CHOICE_SCENE: String = "res://scenes/ui/choice_screen.tscn"
const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const VILLAGER_SCENE: PackedScene = preload("res://scenes/village/villager.tscn")
const CEREMONY_SCENE: PackedScene = preload("res://scenes/ui/gift_ceremony.tscn")
## Where the hero stands for a lesson: beside the Master (below would cover their prompt).
const LESSON_STEP: Vector2 = Vector2(30, 4)
const GOLD: Color = Color(1, 0.82, 0.45)
## Where the hero stands after leaving the Shrine: just below it.
const SHRINE_STEP: Vector2 = Vector2(0, 44)
## Until a region picker exists (M7), the gate leads to the first region.
const START_REGION: StringName = &"mossy_hollow"
const SHRINE: StringName = &"shrine"
const GATE: StringName = &"gate"
const BOARD: StringName = &"board"
const SHRINE_COLOR: Color = Color(1, 0.82, 0.45)
const GATE_COLOR: Color = Color(0.7, 0.9, 0.6)
const BOARD_COLOR: Color = Color(0.85, 0.75, 0.6)
const INK: Color = Color(0.95, 0.9, 0.78)

var village: VillageState
var balance: BalanceData
## Villagers in the scene, by plot order.
var villagers: Array[Villager] = []
var shrine: InteractSpot
var gate: InteractSpot
var board: InteractSpot

var _leaving: bool = false
## Save the profile when a ceremony ends (tests turn it off).
var save_on_change: bool = true
## The open shop, or null.
var shop: ShopPanel
## The gift ceremony while it plays, or null.
var ceremony: GiftCeremony
## The rank-up, lesson or Renown moment playing, or null.
var moment: VillageMoment
## The character sheet while open, or null.
var sheet: CharacterSheet
## Moments waiting to play after the current one (callables that start one).
var _moments: Array[Callable] = []
var _renown_label: Label

@onready var hero: Hero = $Actors/Hero
@onready var camera: GameCamera = $Camera
@onready var room: PlaceholderRoom = $Room
@onready var actors: Node2D = $Actors
@onready var plots: Node2D = $Plots
@onready var sign_label: Label = %SignLabel


func _ready() -> void:
	village = GameState.profile.village
	balance = hero.balance
	hero.apply_progress(GameState.hero_state(hero.player_id))
	if SceneRouter.context.get("from", "") == "shrine":
		hero.position = $Spots/Shrine.position + SHRINE_STEP
	hero.reset_physics_interpolation()
	_fit_camera()
	$Overlay/Help.text = "Move %s    Use %s    Hero %s    Title %s" % [
		InputBindings.move_hint(), InputBindings.hint(&"interact"), InputBindings.hint(&"map"), InputBindings.hint(&"pause")]
	shrine = _add_spot(SHRINE, $Spots/Shrine.position, SHRINE_COLOR)
	gate = _add_spot(GATE, $Spots/Gate.position, GATE_COLOR)
	board = _add_spot(BOARD, $Spots/Board.position, BOARD_COLOR)
	board.caption = "Notice board"
	_place_villagers()
	_add_renown_label()
	refresh()
	_say(welcome())
	var gift: Variant = SceneRouter.context.get("ceremony", {})
	if gift is Dictionary and not (gift as Dictionary).is_empty():
		play_ceremony(StringName(str(gift.get("villager_id", ""))), bool(gift.get("first_gift", false)))
	else:
		grow()


## The sign's first line: the Elder's words while the first gift waits.
func welcome() -> String:
	if _offer_waits() and FirstGift.is_active(GameState.profile, balance):
		var data: VillagerData = _villager_data(balance.first_gift_villager)
		return "The Elder: \"Your first Spark! Bring it to the Shrine. %s could use it.\"" % (data.display_name if data != null else "A villager")
	return "A power waits at the Shrine." if _offer_waits() else "Welcome home to Emberwick."


func _unhandled_input(event: InputEvent) -> void:
	if busy():
		return
	if event.is_action_pressed(&"pause") and not _leaving:
		get_viewport().set_input_as_handled()
		_leaving = true
		SceneRouter.go(TITLE_SCENE)
	elif event.is_action_pressed(&"map") and not _leaving:
		get_viewport().set_input_as_handled()
		open_sheet(hero)


## Updates the Shrine, gate, houses and villagers from the saved state.
func refresh() -> void:
	var offer: Array[StringName] = GameState.hero_state(hero.player_id).power_offer
	shrine.caption = "Shrine: your first Spark waits" if not offer.is_empty() and FirstGift.is_active(GameState.profile, balance) \
			else "Shrine: a power waits" if not offer.is_empty() \
			else "Shrine: grow stronger" if GrowthPanel.has_anything_to_spend(GameState.hero_state(hero.player_id), balance) else "Shrine"
	var waiting: PowerData = ContentDB.get_item(&"powers", PowerOffer.waiting_power(GameState.hero_state(hero.player_id))) as PowerData \
			if offer.size() == 1 else null
	shrine.icon_shape = waiting.icon_shape if waiting != null else &""
	gate.caption = "Gate: continue your run" if GameState.has_saved_run() else "Gate: %s" % _region_name()
	for plot: VillagePlot in plots.get_children():
		var state: VillagerState = village.on_plot(plot.index)
		var data: VillagerData = _villager_data(state.villager_id) if state != null else null
		var power: PowerData = ContentDB.get_item(&"powers", state.power_id) as PowerData if state != null and state.has_power() else null
		plot.set_resident(data, power, TrainingSystem.rank(state, balance) if state != null else TrainingSystem.NONE)
	for villager: Villager in villagers:
		villager.setup(villager.data, villager.state, balance)
	_renown_label.text = RenownSystem.text(village, balance)


## True while a shop, the character sheet, the gift ceremony or a moment holds the hero still.
func busy() -> bool:
	return shop != null or sheet != null or ceremony != null or moment != null


## Shrine: the Choice screen. Gate: a run. Board: the village news.
func use_spot(spot: InteractSpot, by: Hero) -> void:
	if _leaving or busy():
		return
	match spot.kind:
		SHRINE:
			_leaving = true
			SceneRouter.go(CHOICE_SCENE, {"player_id": by.player_id})
		GATE:
			if _offer_waits():
				_say("A power waits at the Shrine. Settle it before you set out.")
			else:
				start_run()
		BOARD:
			_say(board_text())


## The notice board: Renown and who comes next, then the runs so far.
func board_text() -> String:
	var renown_level: int = RenownSystem.level(village, balance)
	var text: String = "%s." % RenownSystem.text(village, balance)
	var next: int = RenownSystem.next_level_points(renown_level, balance)
	var coming: Array[VillagerData] = RenownSystem.arrivals_at(renown_level + 1, GameState.roster())
	if next > 0 and not coming.is_empty():
		text += " At Renown %d, %s moves in." % [renown_level + 1, coming[0].title()]
	text += " Gifts give Renown, Masters more."
	return text + "\nNo raids are coming yet. Runs so far: %d, cleared: %d." % [GameState.profile.run_count, GameState.profile.runs_won]


## Leaves through the gate into the run.
func start_run() -> void:
	_leaving = true
	prepare_run()
	SceneRouter.go(RUN_ROOM_SCENE)


## Puts the saved run back in GameState.run, or starts a new one.
func prepare_run() -> void:
	if GameState.has_saved_run() and GameState.load_saved_run():
		return
	var region: RegionData = ContentDB.get_item(&"regions", START_REGION) as RegionData
	var seed_value: int = randi()
	GameState.run = RunState.start(region, seed_value)
	EventBus.run_started.emit(region.id, seed_value)


## What a villager says: their service now, and the line for their gift. A villager who
## sells something opens their shop too.
func talk(villager: Villager, by: Hero = hero) -> void:
	if busy():
		return
	_say(speech(villager))
	if ShopPanel.sells_anything(villager.data, villager.state):
		open_shop(villager, by)


func speech(villager: Villager) -> String:
	var data: VillagerData = villager.data
	var base: String = _service_text(data.base_service)
	if not villager.state.has_power():
		return "%s: \"%s\"\n%s" % [data.title(), data.greeting, base]
	var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(data.id, villager.state.power_id)) as ComboData
	var power_name: String = villager.power.display_name if villager.power != null else String(villager.state.power_id)
	if combo == null:
		return "%s holds %s." % [data.title(), power_name]
	var service: String = _service_text(combo.novice)
	if villager.rank >= TrainingSystem.ADEPT:
		service += " Adept: " + _service_text(combo.adept)
	if villager.rank == TrainingSystem.MASTER and combo.technique != null:
		service += " Taught you %s." % combo.technique.display_name
	return "%s (%s, %s): \"%s\"\n%s %s" % [data.title(), power_name, villager.progress, combo.gift_line, base, service]


## Plays the gift ceremony for the villager who was just given a power. The hero stands
## still and the camera follows the Spark until it ends. Returns null if they hold none.
func play_ceremony(villager_id: StringName, first_gift: bool = false) -> GiftCeremony:
	var villager: Villager = villager_node(villager_id)
	if villager == null or villager.power == null:
		return null
	var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(villager_id, villager.state.power_id)) as ComboData
	var service: String = ""
	if combo != null and combo.novice != null:
		service = "New service: " + _service_text(combo.novice)
		if combo.novice.price > 0:
			service += " Buy it once at the %s for %d coins." % [villager.data.workplace, combo.novice.price]
	var line: String = "\"%s\"" % combo.gift_line if combo != null and not combo.gift_line.is_empty() else ""
	ceremony = CEREMONY_SCENE.instantiate()
	actors.add_child(ceremony)
	ceremony.setup(hero, villager, _plot_of(villager.state), villager.power,
			"%s for %s" % [villager.power.display_name, villager.data.title()], line, service, GameState.profile.ceremonies_seen)
	ceremony.finished.connect(_on_ceremony_finished.bind(villager, first_gift))
	camera.target = ceremony.focus
	# The sign and help would show through the ceremony's bars.
	$Overlay.visible = false
	hero.velocity = Vector2.ZERO
	hero.set_physics_process(false)
	return ceremony


func _on_ceremony_finished(villager: Villager, first_gift: bool) -> void:
	ceremony = null
	$Overlay.visible = true
	GameState.profile.ceremonies_seen += 1
	if save_on_change:
		GameState.save_profile()
	camera.target = hero
	# Next frame, so the press that ended the ceremony does not also act.
	hero.set_physics_process.call_deferred(true)
	EventBus.gift_ceremony_finished.emit(village.villagers.find(villager.state))
	if first_gift:
		_say("The Elder: \"Well done. A Spark grows when it is shared. From now on, the Choice is yours.\"")
	else:
		_say("%s holds %s now." % [villager.data.title(), villager.power.display_name])
	grow()


# --- Training and Renown (docs/GDD.md Sections 5.2 and 5.5) -------------------------

## Once nothing waits at the Shrine: applies the runs' training ticks, teaches the hero
## every new Master's Technique, moves in the villagers a new Renown level brings, saves,
## and plays a moment for each rank-up, then each lesson, then each new Renown level.
## Returns the rank-ups.
func grow() -> Array[RankUp]:
	if _offer_waits():
		return []
	var rank_ups: Array[RankUp] = TrainingSystem.train_due(GameState.profile, balance)
	for event: RankUp in rank_ups:
		EventBus.villager_ranked_up.emit(village.index_of(event.villager_id), event.rank_after)
	var renown_level: int = RenownSystem.level(village, balance)
	if village.renown_seen < 0:
		village.renown_seen = renown_level
	var arrivals: Array[VillagerState] = []
	var levels: Array[int] = []
	if renown_level > village.renown_seen:
		arrivals = GameState.admit_villagers(renown_level)
		for level: int in range(maxi(village.renown_seen, 0) + 1, renown_level + 1):
			levels.append(level)
		village.renown_seen = renown_level
		EventBus.renown_changed.emit(RenownSystem.points(village, balance), renown_level)
	var lessons: Array[ComboData] = teach()
	if rank_ups.is_empty() and levels.is_empty() and lessons.is_empty():
		return rank_ups
	if save_on_change:
		GameState.save_profile()
	for state: VillagerState in arrivals:
		_add_villager(state).modulate.a = 0.0
	refresh()
	for event: RankUp in rank_ups:
		_moments.append(play_rank_up.bind(event))
	for combo: ComboData in lessons:
		_moments.append(play_lesson.bind(combo))
	for level: int in levels:
		_moments.append(play_renown.bind(level, arrivals))
	_next_moment()
	return rank_ups


## Plays the next waiting moment, if any.
func _next_moment() -> void:
	if moment != null or ceremony != null:
		return
	while not _moments.is_empty():
		var start: Callable = _moments.pop_front()
		if start.call() != null:
			return
	# Nothing left to play: every newcomer stands in full view.
	for villager: Villager in villagers:
		villager.modulate.a = 1.0


## A villager reached Adept or Master: their new star or crown and pennant grow in.
func play_rank_up(event: RankUp) -> VillageMoment:
	var villager: Villager = villager_node(event.villager_id)
	if villager == null or villager.power == null:
		return null
	var plot: VillagePlot = _plot_of(villager.state)
	var title: String = "%s is now %s!" % [villager.data.display_name, TrainingSystem.rank_name(event.rank_after)]
	var line: String = "\"I have mastered %s. Soon I can teach you what I learned.\"" % villager.power.display_name \
			if event.is_master() else "\"%s comes easier every day. I can do more now.\"" % villager.power.display_name
	var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(event.villager_id, event.power_id)) as ComboData
	var detail: String = ""
	if event.is_master():
		detail = "Master! +%d Renown." % balance.renown_per_master
	elif combo != null and combo.adept != null:
		detail = "Adept: " + _service_text(combo.adept)
	var reveal: Callable = func(amount: float) -> void:
		villager.rank_blend = amount
		if plot != null:
			plot.rank_blend = amount
	return _start_moment(villager, villager.power.color, title, line, detail, reveal)


## Every Master whose Technique the hero does not know teaches it now. Returns their
## combos (the lessons to show).
func teach() -> Array[ComboData]:
	var state: HeroState = GameState.hero_state(hero.player_id)
	var lessons: Array[ComboData] = TechniqueSystem.lessons(state, village, balance, GameState.combos())
	for combo: ComboData in lessons:
		if TechniqueSystem.learn(state, combo.technique.id):
			EventBus.technique_learned.emit(hero.player_id, combo.technique.id)
	return lessons


## A Master calls the hero over and teaches them their Technique.
func play_lesson(combo: ComboData) -> VillageMoment:
	var villager: Villager = villager_node(combo.villager_id)
	if villager == null or combo.technique == null:
		return null
	hero.global_position = villager.global_position + LESSON_STEP
	hero.facing = Vector2.LEFT
	hero.reset_physics_interpolation()
	var technique: TechniqueData = combo.technique
	var title: String = "%s teaches you %s!" % [villager.data.display_name, technique.display_name]
	var line: String = "\"%s\"" % technique.lesson_line if not technique.lesson_line.is_empty() else ""
	var detail: String = "Technique: %s Always active, never takes a slot." % technique.description
	var tint: Color = villager.power.color if villager.power != null else GOLD
	var glow: Callable = func(amount: float) -> void:
		hero.visual.modulate = Color.WHITE.lerp(tint.lightened(0.4), sin(amount * PI))
	return _start_moment(villager, tint, title, line, detail, glow)


## A new Renown level: whoever moves in at it fades in on their plot.
func play_renown(level: int, arrivals: Array[VillagerState]) -> VillageMoment:
	var newcomer: Villager = null
	for state: VillagerState in arrivals:
		var data: VillagerData = _villager_data(state.villager_id)
		if data != null and data.arrives_at_renown == level:
			newcomer = villager_node(state.villager_id)
			break
	var title: String = "Renown %d!" % level
	if newcomer == null:
		_say("%s! Emberwick is growing." % title)
		return null
	var line: String = "\"%s\"" % newcomer.data.greeting
	var detail: String = "%s moves in. %s" % [newcomer.data.title(), _service_text(newcomer.data.base_service)]
	var reveal: Callable = func(amount: float) -> void: newcomer.modulate.a = amount
	return _start_moment(newcomer, GOLD, title, line, detail, reveal)


func _start_moment(villager: Villager, tint: Color, title: String, line: String, detail: String, reveal: Callable) -> VillageMoment:
	moment = VillageMoment.new()
	moment.name = "Moment"
	actors.add_child(moment)
	# A villager low on the map would stand under the dialogue box: move the box up.
	moment.setup(villager, tint, title, line, detail, reveal, villager.position.y > room.get_rect().get_center().y)
	moment.finished.connect(_on_moment_finished.bind(title))
	camera.target = moment.focus
	$Overlay.visible = false
	hero.velocity = Vector2.ZERO
	hero.set_physics_process(false)
	return moment


func _on_moment_finished(title: String) -> void:
	moment = null
	_say(title)
	_next_moment()
	if moment != null:
		return
	$Overlay.visible = true
	camera.target = hero
	# Next frame, so the press that ended the moment does not also act.
	hero.set_physics_process.call_deferred(true)


## The villager node for this job, or null.
func villager_node(villager_id: StringName) -> Villager:
	for villager: Villager in villagers:
		if villager.state.villager_id == villager_id:
			return villager
	return null


func _plot_of(state: VillagerState) -> VillagePlot:
	for plot: VillagePlot in plots.get_children():
		if plot.index == state.plot:
			return plot
	return null


## Opens the character sheet; the hero stands still until it closes.
func open_sheet(by: Hero) -> CharacterSheet:
	if busy():
		return null
	sheet = CharacterSheet.new()
	sheet.setup(by.player_id, balance)
	sheet.closed.connect(_on_sheet_closed.bind(by))
	$Overlay.add_child(sheet)
	sheet.position = Vector2(110, 24)
	by.velocity = Vector2.ZERO
	by.set_physics_process(false)
	return sheet


func _on_sheet_closed(by: Hero) -> void:
	sheet = null
	by.set_physics_process.call_deferred(true)


## Opens `villager`'s shop; the hero stands still until it closes.
func open_shop(villager: Villager, by: Hero) -> ShopPanel:
	shop = ShopPanel.new()
	shop.setup(by.player_id, villager.state, villager.data, by.weapon, balance)
	shop.closed.connect(_on_shop_closed.bind(by))
	shop.bought.connect(func(_item: StringName) -> void: _on_bought(by))
	$Overlay.add_child(shop)
	shop.position = Vector2(170, 60)
	by.velocity = Vector2.ZERO
	by.set_physics_process(false)
	return shop


func _on_shop_closed(by: Hero) -> void:
	shop = null
	refresh()
	# Next frame, so the press that closed the shop does not also dodge.
	by.set_physics_process.call_deferred(true)


## A new weapon tier shows at once on the hero in the village.
func _on_bought(by: Hero) -> void:
	by.apply_progress(GameState.hero_state(by.player_id))


func _service_text(service: ServiceData) -> String:
	if service == null:
		return ""
	if service.only_in_raids():
		return service.description + " (Raids have not started yet.)"
	return service.description


func _place_villagers() -> void:
	for plot: VillagePlot in plots.get_children():
		var state: VillagerState = village.on_plot(plot.index)
		if state != null:
			_add_villager(state)


## Puts a villager in front of their house. Returns null if their data is missing.
func _add_villager(state: VillagerState) -> Villager:
	var data: VillagerData = _villager_data(state.villager_id)
	var plot: VillagePlot = _plot_of(state)
	if data == null or plot == null:
		return null
	var villager: Villager = VILLAGER_SCENE.instantiate()
	actors.add_child(villager)
	villager.position = plot.position
	villager.setup(data, state, balance)
	villager.talked_to.connect(func(who: Villager, by: Hero) -> void: talk(who, by))
	villagers.append(villager)
	return villager



## "Renown 1 (1/4)" in the top right corner.
func _add_renown_label() -> void:
	_renown_label = Label.new()
	_renown_label.name = "Renown"
	_renown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_renown_label.position = Vector2(440, 6)
	_renown_label.size = Vector2(192, 14)
	_renown_label.add_theme_font_size_override("font_size", 9)
	_renown_label.add_theme_color_override("font_color", GOLD)
	_renown_label.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.05))
	_renown_label.add_theme_constant_override("outline_size", 3)
	$Overlay.add_child(_renown_label)


func _add_spot(kind: StringName, at: Vector2, tint: Color) -> InteractSpot:
	var spot: InteractSpot = InteractSpot.create(kind, "", tint)
	spot.name = String(kind).capitalize()
	spot.position = at
	spot.chosen.connect(use_spot)
	$Spots.add_child(spot)
	return spot


func _offer_waits() -> bool:
	return not GameState.hero_state(hero.player_id).power_offer.is_empty()


func _region_name() -> String:
	var region: RegionData = ContentDB.get_item(&"regions", START_REGION) as RegionData
	return region.display_name if region != null else "the wilds"


func _villager_data(villager_id: StringName) -> VillagerData:
	return ContentDB.get_item(&"villagers", villager_id) as VillagerData


func _say(text: String) -> void:
	sign_label.text = text


func _fit_camera() -> void:
	var bounds: Rect2 = room.get_rect()
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)
	camera.global_position = hero.global_position
	camera.reset_smoothing()
	camera.reset_physics_interpolation()
