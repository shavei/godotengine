extends GutTest
## Techniques (M5 PR 2): TechniqueData content for the 16 prototype combos, TechniqueSystem
## (lessons, learning, save), each Technique's effect on the hero, the run room's floor
## rules (Second Serving, Second Wind), the village's lesson moment and the character sheet.

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero/hero.tscn")
const VILLAGE_SCENE: PackedScene = preload("res://scenes/village/village.tscn")
const ROOM_SCENE: PackedScene = preload("res://scenes/run/room.tscn")
const PROTOTYPE_VILLAGERS: Array[StringName] = [&"smith", &"farmer", &"guard", &"healer"]
const PROTOTYPE_POWERS: Array[StringName] = [&"fire", &"frost", &"stone", &"growth"]
## Every target a Technique may use.
const TECHNIQUE_TARGETS: Array[StringName] = [
	ModifierStack.MAX_HP, ModifierStack.FIRST_HIT_TAKEN, ModifierStack.HEAL_ON_KILL,
	ModifierStack.FLASK_BURN_TIME, ModifierStack.CALM_REGEN, ModifierStack.STEADY_ATTACKS,
	ModifierStack.STEADY, ModifierStack.POWER_DAMAGE, ModifierStack.ATTACK_SPEED,
	ModifierStack.CHILL_ATTACKERS, ModifierStack.THORNS, ModifierStack.FLOOR_HEAL, ModifierStack.FREE_FLASKS,
]

var _balance: BalanceData
var _original_profile: ProfileState
var _original_context: Dictionary
var _original_dir: String
var world: Node2D
var hero: Hero
var input: InputSource


func before_all() -> void:
	_original_dir = SaveManager.save_dir
	SaveManager.save_dir = "user://test_saves_techniques"


func after_all() -> void:
	SaveManager.save_dir = _original_dir


func before_each() -> void:
	HitStop.enabled = false
	_balance = ContentDB.get_item(&"balance", &"default") as BalanceData
	_original_profile = GameState.profile
	_original_context = SceneRouter.context
	SceneRouter.context = {}
	GameState.new_profile()
	GameState.admit_villagers(2)
	GameState.profile.first_gift_done = true
	hero = null


func after_each() -> void:
	HitStop.enabled = true
	Engine.time_scale = 1.0
	GameState.profile = _original_profile
	SceneRouter.context = _original_context
	GameState.run = null
	SaveManager.delete_slot(GameState.slot)


func _hero_state() -> HeroState:
	return GameState.hero_state(0)


func _village() -> VillageState:
	return GameState.profile.village


func _technique(id: StringName) -> TechniqueData:
	return ContentDB.get_item(&"techniques", id) as TechniqueData


func _give(villager_id: StringName, power_id: StringName, level: int = 1) -> VillagerState:
	return GiftSystem.give(_village(), _village().index_of(villager_id), power_id, level)


## Spawns a hero that knows `ids`, with the village's services and the Techniques applied.
func _spawn(ids: Array[StringName] = []) -> Hero:
	for id: StringName in ids:
		TechniqueSystem.learn(_hero_state(), id)
	world = Node2D.new()
	add_child_autofree(world)
	hero = HERO_SCENE.instantiate()
	input = InputSource.new()
	input.name = "ScriptedInput"
	hero.add_child(input)
	hero.position = Vector2(200, 200)
	world.add_child(hero)
	hero.stats.crit_chance = 0.0
	hero.power_stats.crit_chance = 0.0
	hero.apply_progress(_hero_state())
	hero.apply_services(GameState.services(0))
	hero.apply_techniques(GameState.techniques(0))
	return hero


func _enemy(pos: Vector2, damage: float = 10.0) -> Enemy:
	var enemy: Enemy = Enemy.create(ContentDB.get_item(&"enemies", &"tusk_boar"))
	enemy.position = pos
	world.add_child(enemy)
	var attack: AttackData = AttackData.new()
	attack.damage = damage
	attack.knockback = 200.0
	enemy.hitbox.attack = attack
	enemy.hitbox.stats.crit_chance = 0.0
	return enemy


func _count(kind: Variant) -> int:
	var found: int = 0
	for child: Node in world.get_children():
		if is_instance_of(child, kind) and not child.is_queued_for_deletion():
			found += 1
	return found


# --- Content -------------------------------------------------------------------------

func test_every_prototype_combo_teaches_its_own_technique() -> void:
	var seen: Array[StringName] = []
	for villager_id: StringName in PROTOTYPE_VILLAGERS:
		for power_id: StringName in PROTOTYPE_POWERS:
			var combo: ComboData = ContentDB.get_item(&"combos", ComboData.id_for(villager_id, power_id)) as ComboData
			assert_not_null(combo.technique, "%s_%s" % [villager_id, power_id])
			if combo.technique == null:
				continue
			assert_false(seen.has(combo.technique.id), "one Technique per combo")
			seen.append(combo.technique.id)
			assert_eq(_technique(combo.technique.id), combo.technique, "ContentDB loads it")
	assert_eq(seen.size(), 16)


func test_every_technique_is_described_and_does_something() -> void:
	var modifier_only: int = 0
	for technique: TechniqueData in GameState.all_techniques():
		assert_false(technique.display_name.is_empty(), "%s name" % technique.id)
		assert_false(technique.description.is_empty(), "%s description" % technique.id)
		assert_false(technique.lesson_line.is_empty(), "%s lesson line" % technique.id)
		assert_false(technique.modifiers.is_empty() and technique.behavior_script == null, "%s does something" % technique.id)
		for modifier: ModifierData in technique.modifiers:
			assert_true(TECHNIQUE_TARGETS.has(modifier.target), "%s: %s is a known target" % [technique.id, modifier.target])
		if technique.behavior_script == null:
			modifier_only += 1
		else:
			assert_true(technique.behavior_script.new() is TechniqueBehavior, "%s behavior" % technique.id)
	assert_gte(modifier_only, roundi(GameState.all_techniques().size() * 0.7), "ARCHITECTURE: at least 70% are pure modifiers")


# --- TechniqueSystem --------------------------------------------------------------------

func test_only_a_master_has_a_lesson_and_it_is_learned_once() -> void:
	var smith: VillagerState = _give(&"smith", &"fire")
	var combos: Array[ComboData] = GameState.combos()
	assert_eq(TechniqueSystem.lessons(_hero_state(), _village(), _balance, combos).size(), 0, "a Novice has nothing to teach")
	smith.training_points = _balance.master_tp
	var lessons: Array[ComboData] = TechniqueSystem.lessons(_hero_state(), _village(), _balance, combos)
	assert_eq(lessons.size(), 1)
	assert_eq(lessons[0].technique.id, &"ember_step")
	assert_true(TechniqueSystem.learn(_hero_state(), &"ember_step"))
	assert_false(TechniqueSystem.learn(_hero_state(), &"ember_step"), "never twice")
	assert_true(TechniqueSystem.knows(_hero_state(), &"ember_step"))
	assert_eq(TechniqueSystem.lessons(_hero_state(), _village(), _balance, combos).size(), 0)
	assert_eq(TechniqueSystem.teacher(combos, &"ember_step").villager_id, &"smith")


func test_lessons_are_per_hero() -> void:
	_give(&"guard", &"stone", 8)
	TechniqueSystem.learn(_hero_state(), &"stoneguard")
	var second: HeroState = GameState.hero_state(1)
	assert_eq(TechniqueSystem.lessons(second, _village(), _balance, GameState.combos()).size(), 1, "a co-op hero learns too")


func test_techniques_survive_a_save_round_trip() -> void:
	TechniqueSystem.learn(_hero_state(), &"regrowth")
	TechniqueSystem.learn(_hero_state(), &"fever")
	var loaded: HeroState = HeroState.from_dict(JSON.parse_string(JSON.stringify(_hero_state().to_dict())))
	assert_eq(loaded.techniques, [&"regrowth", &"fever"] as Array[StringName])
	assert_eq(HeroState.from_dict({}).techniques.size(), 0, "old saves know none")


func test_technique_modifiers_join_the_modifier_stack() -> void:
	assert_eq(GameState.services(0).total(ModifierStack.MAX_HP), 0.0)
	TechniqueSystem.learn(_hero_state(), &"stoneguard")
	assert_eq(GameState.services(0).total(ModifierStack.MAX_HP), 20.0)
	_spawn()
	assert_eq(hero.health.max_hp, 120, "Stoneguard: +20 max HP")


# --- Each Technique on the hero -------------------------------------------------------------

func test_anvil_skin_halves_only_the_first_hit_in_a_room() -> void:
	_spawn([&"anvil_skin"])
	var enemy: Enemy = _enemy(Vector2(230, 200), 20.0)
	await wait_physics_frames(1)
	hero.hurtbox.receive_hit(enemy.hitbox)
	assert_eq(hero.health.hp, 90, "10 of 20")
	hero.grant_iframes(0.0)
	hero._iframe_time = 0.0
	hero.hurtbox.invincible = false
	hero.hurtbox.receive_hit(enemy.hitbox)
	assert_eq(hero.health.hp, 70, "the second hit is whole")
	hero.apply_services(GameState.services(0))
	assert_almost_eq(hero.stats.damage_taken_multiplier, 0.5, 0.001, "a new room, a new first hit")


func test_living_steel_heals_on_a_killing_blow() -> void:
	_spawn([&"living_steel"])
	hero.health.take_damage(30)
	var enemy: Enemy = _enemy(Vector2(230, 200))
	await wait_physics_frames(1)
	var attack: AttackData = AttackData.new()
	attack.damage = 5.0
	hero.hitbox.attack = attack
	var result: DamageResult = enemy.hurtbox.receive_hit(hero.hitbox)
	hero.hitbox.hit_landed.emit(enemy.hurtbox, result)
	assert_eq(hero.health.hp, 70, "no kill, no heal")
	enemy.health.hp = 1
	result = enemy.hurtbox.receive_hit(hero.hitbox)
	hero.hitbox.hit_landed.emit(enemy.hurtbox, result)
	assert_true(enemy.health.is_dead())
	assert_eq(hero.health.hp, 71, "a kill heals 1")


func test_hearth_heart_burns_weapon_hits_after_a_flask() -> void:
	_spawn([&"hearth_heart"])
	var enemy: Enemy = _enemy(Vector2(300, 300))
	await wait_physics_frames(1)
	hero.apply_infusions(enemy.hurtbox, AttackData.new())
	assert_false(enemy.status.has(StatusEffects.BURN), "no flask yet")
	hero.flask_drunk(10)
	assert_true(hero.is_hearth_burning())
	hero.apply_infusions(enemy.hurtbox, AttackData.new())
	assert_true(enemy.status.has(StatusEffects.BURN))
	await wait_seconds(0.2)
	hero._hearth_time = 0.05
	await wait_physics_frames(6)
	assert_false(hero.is_hearth_burning(), "it wears off")


func test_second_serving_gives_the_first_flask_back() -> void:
	_spawn([&"second_serving"])
	assert_eq(hero.free_flasks, 1)
	var before: int = hero.flasks.charges
	hero.health.take_damage(50)
	hero.flasks.drink(hero.health.hp, hero.health.max_hp)
	hero.flask_drunk(35)
	assert_eq(hero.flasks.charges, before, "not used up")
	assert_eq(hero.free_flasks, 0)
	hero.flasks.drink(hero.health.hp, hero.health.max_hp)
	hero.flask_drunk(35)
	assert_eq(hero.flasks.charges, before - 1, "the second one is")


func test_regrowth_heals_only_with_no_enemy_around() -> void:
	_spawn([&"regrowth"])
	hero.health.take_damage(20)
	var enemy: Enemy = _enemy(Vector2(400, 400))
	await wait_seconds(1.2)
	assert_eq(hero.health.hp, 80, "an enemy is around")
	enemy.free()
	await wait_seconds(2.1)
	assert_between(hero.health.hp, 82, 83, "1 HP a second")


func test_rooted_stance_keeps_a_swing_going_through_a_hit() -> void:
	_spawn([&"rooted_stance"])
	var enemy: Enemy = _enemy(Vector2(240, 200))
	await wait_physics_frames(1)
	hero.state_machine.transition_to(&"Move")
	hero.hurtbox.receive_hit(enemy.hitbox)
	assert_true(hero.state_machine.is_in(&"Hurt"), "outside a swing it does nothing")
	hero._iframe_time = 0.0
	hero.hurtbox.invincible = false
	hero.knockback.clear()
	hero.state_machine.transition_to(&"Attack")
	hero.hurtbox.receive_hit(enemy.hitbox)
	assert_true(hero.state_machine.is_in(&"Attack"), "the swing goes on")
	assert_eq(hero.knockback.velocity, Vector2.ZERO, "no knockback")


func test_iron_bones_never_staggers_or_knocks_back() -> void:
	_spawn([&"iron_bones"])
	var enemy: Enemy = _enemy(Vector2(240, 200))
	await wait_physics_frames(1)
	hero.state_machine.transition_to(&"Move")
	hero.hurtbox.receive_hit(enemy.hitbox)
	assert_eq(hero.health.hp, 90, "it still hurts")
	assert_true(hero.state_machine.is_in(&"Move"))
	assert_eq(hero.knockback.velocity, Vector2.ZERO)


func test_rally_flame_and_fever_wake_at_low_hp() -> void:
	_spawn([&"rally_flame", &"fever"])
	assert_eq(hero.power_stats.damage_bonus, 0.0)
	assert_eq(hero.attack_speed, 1.0)
	hero.health.take_damage(55)
	assert_almost_eq(hero.attack_speed, 1.2, 0.001, "Fever below 50%")
	assert_eq(hero.power_stats.damage_bonus, 0.0, "Rally Flame waits for 30%")
	hero.health.take_damage(20)
	assert_almost_eq(hero.power_stats.damage_bonus, 0.3, 0.001, "Rally Flame below 30%")
	hero.health.heal(60)
	assert_eq(hero.power_stats.damage_bonus, 0.0, "healed back up")
	assert_eq(hero.attack_speed, 1.0)


func test_fever_speeds_up_the_swing() -> void:
	_spawn([&"fever"])
	hero.health.take_damage(60)
	var attack: AttackData = hero.weapon.combo[0]
	var swing: float = attack.windup + attack.active + attack.recovery
	input.press(&"attack")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Attack"))
	await wait_seconds(swing / 1.2 + 0.05)
	assert_false(hero.state_machine.is_in(&"Attack"), "done sooner than a normal swing")


func test_hold_the_line_and_thornmail_answer_a_close_attacker() -> void:
	_spawn([&"hold_the_line", &"thornmail"])
	var enemy: Enemy = _enemy(Vector2(240, 200))
	await wait_physics_frames(1)
	var enemy_hp: int = enemy.health.hp
	hero.hurtbox.receive_hit(enemy.hitbox)
	assert_true(enemy.status.has(StatusEffects.CHILL), "Hold the Line")
	assert_eq(enemy.health.hp, enemy_hp - 5, "Thornmail")


func test_a_projectile_is_not_answered() -> void:
	_spawn([&"hold_the_line", &"thornmail"])
	var arrow: HitboxComponent = HitboxComponent.new()
	arrow.attack = AttackData.new()
	arrow.attack.damage = 5.0
	world.add_child(arrow)
	await wait_physics_frames(1)
	hero.hurtbox.receive_hit(arrow)
	assert_eq(hero.health.hp, 95, "the hit lands, nothing to answer")


func test_ember_step_leaves_fire_behind_a_dodge() -> void:
	_spawn([&"ember_step"])
	assert_eq(hero.technique_behaviors().size(), 1)
	input.move = Vector2.RIGHT
	input.press(&"dodge")
	await wait_seconds(_balance.dodge_duration + 0.05)
	assert_gte(_count(PowerPatch), 3, "a patch at the start and every 20 px")
	var enemy: Enemy = _enemy(hero.global_position + Vector2(-20, 0))
	await wait_seconds(0.6)
	assert_true(enemy.status.has(StatusEffects.BURN), "the trail burns")


func test_cold_temper_chills_on_a_perfect_dodge_only() -> void:
	_spawn([&"cold_temper"])
	var enemy: Enemy = _enemy(Vector2(240, 200))
	var far: Enemy = _enemy(Vector2(400, 200))
	await wait_physics_frames(1)
	watch_signals(hero)
	input.move = Vector2.LEFT
	input.press(&"dodge")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Dodge"))
	hero.hurtbox.receive_hit(enemy.hitbox)
	hero.hurtbox.receive_hit(enemy.hitbox)
	assert_signal_emit_count(hero, "perfect_dodge", 1, "once per dodge")
	assert_true(enemy.status.has(StatusEffects.CHILL))
	assert_false(far.status.has(StatusEffects.CHILL), "only enemies nearby")
	assert_eq(hero.health.hp, 100, "the dodge still avoids the hit")


func test_cold_blood_slows_time_once_when_hp_drops_low() -> void:
	_spawn([&"cold_blood"])
	hero.balance = hero.balance.duplicate()
	hero.balance.cold_blood_duration = 0.2
	hero.health.take_damage(60)
	assert_eq(Engine.time_scale, 1.0, "40% is not low yet")
	hero.health.take_damage(15)
	assert_almost_eq(Engine.time_scale, hero.balance.cold_blood_time_scale, 0.001)
	assert_true(HitStop.is_slowed())
	await wait_seconds(0.4, "real time")
	assert_eq(Engine.time_scale, 1.0)
	hero.health.heal(50)
	hero.health.take_damage(60)
	assert_eq(Engine.time_scale, 1.0, "once a room")


func test_a_freeze_during_a_slow_returns_to_the_slow() -> void:
	HitStop.enabled = true
	HitStop.slow(get_tree(), 0.5, 0.4)
	HitStop.request(get_tree(), 0.05)
	assert_almost_eq(Engine.time_scale, HitStop.frozen_scale, 0.001)
	await wait_seconds(0.15)
	assert_almost_eq(Engine.time_scale, 0.5, 0.001, "back to the slow, not full speed")
	await wait_seconds(0.4)
	assert_eq(Engine.time_scale, 1.0)


# --- Run rooms ------------------------------------------------------------------------

func _room(run: RunState) -> RunRoom:
	GameState.run = run
	var room: RunRoom = ROOM_SCENE.instantiate()
	add_child_autofree(room)
	await wait_physics_frames(3)
	return room


func test_rooms_give_the_hero_their_technique_behaviors() -> void:
	TechniqueSystem.learn(_hero_state(), &"ember_step")
	TechniqueSystem.learn(_hero_state(), &"stoneguard")
	var room: RunRoom = await _room(RunState.start(ContentDB.get_item(&"regions", &"mossy_hollow"), 3))
	assert_eq(room.hero.technique_behaviors().size(), 1)
	assert_eq(room.hero.health.max_hp, 120)


func test_second_wind_heals_on_a_new_floor_only() -> void:
	TechniqueSystem.learn(_hero_state(), &"second_wind")
	var run: RunState = RunState.start(ContentDB.get_item(&"regions", &"mossy_hollow"), 3)
	run.save_hero(0, 50, 100, 1, 0, 0, run.floor_index)
	var room: RunRoom = await _room(run)
	assert_eq(room.hero.health.hp, 50, "same floor")
	room.queue_free()
	run.save_hero(0, 50, 100, 1, 0, 0, run.floor_index - 1)
	room = await _room(run)
	assert_eq(room.hero.health.hp, 65, "a new floor: +15%")


func test_second_serving_flasks_carry_within_a_floor_and_refill_on_the_next() -> void:
	TechniqueSystem.learn(_hero_state(), &"second_serving")
	var run: RunState = RunState.start(ContentDB.get_item(&"regions", &"mossy_hollow"), 3)
	run.save_hero(0, 50, 100, 1, 0, 0, run.floor_index, 0)
	var room: RunRoom = await _room(run)
	assert_eq(room.hero.free_flasks, 0, "used on this floor")
	room.queue_free()
	run.save_hero(0, 50, 100, 1, 0, 0, run.floor_index - 1, 0)
	room = await _room(run)
	assert_eq(room.hero.free_flasks, 1, "a new floor")
	var saved: RunState = RunState.from_dict(JSON.parse_string(JSON.stringify(run.to_dict())), run.region)
	assert_eq(int(saved.hero_snapshot(0)["floor"]), run.floor_index - 1, "the floor is saved")


# --- The village --------------------------------------------------------------------------

func _open_village() -> Village:
	var scene: Village = VILLAGE_SCENE.instantiate()
	scene.save_on_change = false
	add_child_autofree(scene)
	await wait_physics_frames(2)
	return scene


func test_a_new_master_teaches_their_technique_in_a_lesson() -> void:
	watch_signals(EventBus)
	_give(&"farmer", &"growth", 7)
	GameState.profile.training_due = 1
	var scene: Village = await _open_village()
	assert_true(TechniqueSystem.knows(_hero_state(), &"regrowth"), "learned with the tick")
	assert_signal_emitted_with_parameters(EventBus, "technique_learned", [0, &"regrowth"])
	assert_eq((scene.moment.find_child("Title", true, false) as Label).text, "Tilly is now Master!")
	scene.moment.step(VillageMoment.DURATION)
	var lesson: VillageMoment = scene.moment
	assert_not_null(lesson, "the lesson follows the rank-up")
	assert_eq((lesson.find_child("Title", true, false) as Label).text, "Tilly teaches you Regrowth!")
	assert_true((lesson.find_child("Detail", true, false) as Label).text.begins_with("Technique: Regenerate"))
	var tilly: Villager = scene.villager_node(&"farmer")
	assert_eq(scene.hero.global_position, tilly.global_position + Village.LESSON_STEP, "called over")
	lesson.step(VillageMoment.DURATION)
	assert_eq(scene.hero.visual.modulate, Color.WHITE, "the glow fades")
	assert_true(scene.speech(tilly).contains("Taught you Regrowth."))


func test_a_master_from_an_old_save_teaches_on_the_next_visit() -> void:
	_give(&"guard", &"stone", 9)
	_village().renown_seen = 2
	var scene: Village = await _open_village()
	assert_true(TechniqueSystem.knows(_hero_state(), &"stoneguard"))
	assert_eq((scene.moment.find_child("Title", true, false) as Label).text, "Maren teaches you Stoneguard!")
	scene.moment.step(VillageMoment.DURATION)
	assert_null(scene.moment)
	scene.queue_free()
	var again: Village = await _open_village()
	assert_null(again.moment, "taught once")


func test_the_character_sheet_lists_what_the_hero_has() -> void:
	_give(&"smith", &"fire", 8)
	TechniqueSystem.learn(_hero_state(), &"ember_step")
	_hero_state().kept_powers.append(KeptPower.create(&"frost", 2))
	_village().renown_seen = 2
	var scene: Village = await _open_village()
	var sheet: CharacterSheet = scene.open_sheet(scene.hero)
	assert_not_null(sheet)
	await wait_physics_frames(1)
	assert_true(scene.busy())
	assert_false(scene.hero.is_physics_processing())
	var line: Label = sheet.find_child("EmberStep", true, false) as Label
	assert_not_null(line)
	assert_true(line.text.begins_with("Ember Step: "))
	assert_true(line.text.ends_with("(Taught by Brann the Smith)"))
	assert_eq((sheet.find_child("Powers", true, false) as Label).text, "Kept powers: Frost Lv 2")
	assert_true((sheet.find_child("Level", true, false) as Label).text.begins_with("Level 1"))
	sheet.close()
	await wait_physics_frames(2)
	assert_null(scene.sheet)
	assert_true(scene.hero.is_physics_processing())


func test_the_sheet_says_how_to_learn_a_technique() -> void:
	var sheet: CharacterSheet = CharacterSheet.new()
	sheet.setup(0, _balance)
	add_child_autofree(sheet)
	await wait_physics_frames(1)
	assert_eq((sheet.find_child("None", true, false) as Label).text, "None yet. A villager who reaches Master teaches you one.")
	assert_eq((sheet.find_child("Attributes", true, false) as Label).text, "Might 0    Vigor 0    Focus 0    Max HP in runs: 100")
