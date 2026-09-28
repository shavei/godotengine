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
## Placeholder art until M7.

const RUN_ROOM_SCENE: String = "res://scenes/run/room.tscn"
const CHOICE_SCENE: String = "res://scenes/ui/choice_screen.tscn"
const TITLE_SCENE: String = "res://scenes/main/title.tscn"
const VILLAGER_SCENE: PackedScene = preload("res://scenes/village/villager.tscn")
const CEREMONY_SCENE: PackedScene = preload("res://scenes/ui/gift_ceremony.tscn")
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
	$Overlay/Help.text = "Move %s    Use %s    Title %s" % [
		InputBindings.move_hint(), InputBindings.hint(&"interact"), InputBindings.hint(&"pause")]
	shrine = _add_spot(SHRINE, $Spots/Shrine.position, SHRINE_COLOR)
	gate = _add_spot(GATE, $Spots/Gate.position, GATE_COLOR)
	board = _add_spot(BOARD, $Spots/Board.position, BOARD_COLOR)
	board.caption = "Notice board"
	_place_villagers()
	refresh()
	_say(welcome())
	var gift: Variant = SceneRouter.context.get("ceremony", {})
	if gift is Dictionary and not (gift as Dictionary).is_empty():
		play_ceremony(StringName(str(gift.get("villager_id", ""))), bool(gift.get("first_gift", false)))


## The sign's first line: the Elder's words while the first gift waits.
func welcome() -> String:
	if _offer_waits() and FirstGift.is_active(GameState.profile, balance):
		var data: VillagerData = _villager_data(balance.first_gift_villager)
		return "The Elder: \"Your first Spark! Bring it to the Shrine. %s could use it.\"" % (data.display_name if data != null else "A villager")
	return "A power waits at the Shrine." if _offer_waits() else "Welcome home to Emberwick."


func _unhandled_input(event: InputEvent) -> void:
	if shop != null or ceremony != null:
		return
	if event.is_action_pressed(&"pause") and not _leaving:
		get_viewport().set_input_as_handled()
		_leaving = true
		SceneRouter.go(TITLE_SCENE)


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
		plot.set_resident(data, power)
	for villager: Villager in villagers:
		villager.setup(villager.data, villager.state, balance)


## Shrine: the Choice screen. Gate: a run. Board: the village news.
func use_spot(spot: InteractSpot, by: Hero) -> void:
	if _leaving or shop != null or ceremony != null:
		return
	match spot.kind:
		SHRINE:
			_leaving = true
			SceneRouter.go(CHOICE_SCENE, {"player_id": by.player_id})
		GATE:
			start_run()
		BOARD:
			_say("No raids are coming yet. Runs so far: %d, cleared: %d." % [GameState.profile.run_count, GameState.profile.runs_won])


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
	if shop != null or ceremony != null:
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
	return "%s (%s, %s): \"%s\"\n%s %s" % [data.title(), power_name, TrainingSystem.rank_name(villager.rank), combo.gift_line, base, service]


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
		var data: VillagerData = _villager_data(state.villager_id) if state != null else null
		if data == null:
			continue
		var villager: Villager = VILLAGER_SCENE.instantiate()
		actors.add_child(villager)
		villager.position = plot.position
		villager.setup(data, state, balance)
		villager.talked_to.connect(func(who: Villager, by: Hero) -> void: talk(who, by))
		villagers.append(villager)


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
