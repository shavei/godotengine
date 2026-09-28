extends GutTest
## Kept powers in combat: PowerRules, PowerLoadout, the four prototype powers' content,
## casting from the hero, each ability against dummies and enemies, and the HUD slots.

const HERO_SCENE: PackedScene = preload("res://scenes/actors/hero/hero.tscn")
const DUMMY_SCENE: PackedScene = preload("res://scenes/actors/training_dummy/training_dummy.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const PROTOTYPE_POWERS: Array[StringName] = [&"fire", &"frost", &"stone", &"growth"]

var world: Node2D
var hero: Hero
var input: InputSource


func before_each() -> void:
	HitStop.enabled = false
	world = Node2D.new()
	add_child_autofree(world)
	hero = HERO_SCENE.instantiate()
	input = InputSource.new()
	input.name = "ScriptedInput"
	hero.add_child(input)
	hero.position = Vector2(100, 100)
	world.add_child(hero)
	hero.stats.crit_chance = 0.0
	hero.power_stats.crit_chance = 0.0


func after_each() -> void:
	HitStop.enabled = true
	Engine.time_scale = 1.0


func _power(id: StringName) -> PowerData:
	return ContentDB.get_item(&"powers", id) as PowerData


func _equip(ids: Array[StringName], level: int = 1) -> void:
	var kept: Array[KeptPower] = []
	for id: StringName in ids:
		kept.append(KeptPower.create(id, level))
	hero.equip_powers(kept)


func _dummy(pos: Vector2) -> TrainingDummy:
	var dummy: TrainingDummy = DUMMY_SCENE.instantiate()
	dummy.position = pos
	world.add_child(dummy)
	return dummy


func _enemy(id: StringName, pos: Vector2) -> Enemy:
	var enemy: Enemy = Enemy.create(ContentDB.get_item(&"enemies", id))
	enemy.position = pos
	world.add_child(enemy)
	return enemy


func _cast(slot: int) -> void:
	input.press(Hero.POWER_ACTIONS[slot])
	await wait_physics_frames(int(hero.balance.power_cast_time * 60.0) + 3)


# --- Rules and content --------------------------------------------------------

func test_power_rules_level_and_focus() -> void:
	var balance: BalanceData = BalanceData.new()
	assert_almost_eq(PowerRules.level_multiplier(1, balance), 1.0, 0.001)
	assert_almost_eq(PowerRules.level_multiplier(3, balance), 1.4, 0.001)
	assert_almost_eq(PowerRules.level_multiplier(9, balance), 1.8, 0.001, "capped at level 5")
	var fire: PowerData = _power(&"fire")
	assert_almost_eq(PowerRules.attack_at_level(fire, 2, balance).damage, 24.0, 0.001)
	assert_eq(fire.attack.damage, 20.0, "the content resource is not changed")
	assert_almost_eq(PowerRules.focus_damage_bonus(10, balance), 0.3, 0.001)
	assert_almost_eq(PowerRules.cooldown(fire, 0, balance), 4.0, 0.001)
	assert_almost_eq(PowerRules.cooldown(fire, 20, balance), 4.0 * 0.7, 0.001)


func test_loadout_cooldowns() -> void:
	var loadout: PowerLoadout = PowerLoadout.new(3)
	var list: Array[PowerData] = [_power(&"fire"), _power(&"stone")]
	loadout.set_powers(list, [2, 1] as Array[int])
	assert_eq(loadout.power_count(), 2)
	assert_eq(loadout.slot(0).level, 2)
	assert_null(loadout.slot(2))
	assert_false(loadout.is_ready(2), "an empty slot is never ready")
	assert_true(loadout.is_ready(0))
	loadout.start_cooldown(0, 4.0)
	assert_false(loadout.is_ready(0))
	assert_eq(loadout.cooldown_fraction(0), 1.0)
	loadout.tick(1.0)
	assert_almost_eq(loadout.cooldown_fraction(0), 0.75, 0.001)
	loadout.tick(3.5)
	assert_true(loadout.is_ready(0))
	assert_eq(loadout.cooldown_fraction(0), 0.0)


func test_prototype_powers_are_complete() -> void:
	for id: StringName in PROTOTYPE_POWERS:
		var power: PowerData = _power(id)
		assert_not_null(power, "%s is in data/powers" % id)
		if power == null:
			continue
		assert_ne(power.display_name, "")
		assert_ne(power.ability_name, "")
		assert_not_null(power.attack, "%s has an attack" % id)
		assert_true(power.ability_script != null and power.ability_script.new() is Ability, "%s ability is an Ability" % id)
		assert_between(power.base_cooldown, 4.0, 8.0, "GDD 4.3 cooldowns are 4 to 8 s")
		assert_ne(power.level3_text, "")
		assert_ne(power.level5_text, "")
	assert_eq(_power(&"fire").attack.status, StatusEffects.BURN)
	assert_eq(_power(&"frost").attack.status, StatusEffects.CHILL)
	assert_eq(_power(&"growth").attack.status, StatusEffects.ROOT)
	assert_gt(_power(&"stone").attack.stagger, 0.0)


# --- Casting ------------------------------------------------------------------

func test_hero_equips_kept_powers_from_progress() -> void:
	var progress: HeroState = HeroState.new()
	GiftSystem.keep(progress, &"frost", hero.balance)
	GiftSystem.keep(progress, &"fire", hero.balance)
	GiftSystem.merge(progress, &"fire", hero.balance)
	progress.attributes[HeroState.FOCUS] = 5
	hero.apply_progress(progress)
	assert_eq(hero.powers.slot(0).power.id, &"frost")
	assert_eq(hero.powers.slot(1).level, 2)
	assert_null(hero.powers.slot(2))
	assert_almost_eq(hero.power_stats.damage_bonus, 0.15, 0.001)
	assert_eq(hero.stats.damage_bonus, 0.0, "Focus is not weapon damage")


func test_cast_starts_the_cooldown_and_a_second_press_is_denied() -> void:
	_equip([&"fire"])
	watch_signals(hero)
	input.aim = Vector2.RIGHT
	input.press(&"power_1")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Cast"))
	await wait_physics_frames(int(hero.balance.power_cast_time * 60.0) + 2)
	assert_signal_emitted_with_parameters(hero, "power_cast", [0])
	assert_true(hero.state_machine.is_in(&"Move"))
	assert_false(hero.powers.is_ready(0))
	input.press(&"power_1")
	await wait_physics_frames(2)
	assert_signal_emitted_with_parameters(hero, "power_denied", [0])
	assert_false(hero.state_machine.is_in(&"Cast"))


func test_empty_slot_press_is_denied() -> void:
	watch_signals(hero)
	input.press(&"power_2")
	await wait_physics_frames(2)
	assert_signal_emitted_with_parameters(hero, "power_denied", [1])


func test_dodge_cancels_a_cast_without_spending_the_cooldown() -> void:
	_equip([&"fire"])
	input.press(&"power_1")
	await wait_physics_frames(2)
	input.press(&"dodge")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Dodge"))
	assert_true(hero.powers.is_ready(0))


func test_a_power_cancels_the_swing_recovery() -> void:
	_equip([&"fire"])
	input.aim = Vector2.RIGHT
	input.press(&"attack")
	# Wind-up plus active is 0.14 s; press the power during recovery.
	await wait_physics_frames(11)
	input.press(&"power_1")
	await wait_physics_frames(2)
	assert_true(hero.state_machine.is_in(&"Cast"))


func test_focus_shortens_the_cooldown() -> void:
	_equip([&"fire"])
	hero.focus = 20
	await _cast(0)
	assert_almost_eq(hero.powers.slot(0).duration, 4.0 * 0.7, 0.01)


# --- Abilities ----------------------------------------------------------------

func test_ember_bolt_hits_and_burns() -> void:
	_equip([&"fire"])
	var dummy: TrainingDummy = _dummy(Vector2(180, 100))
	input.aim = Vector2.RIGHT
	await _cast(0)
	await wait_physics_frames(25)
	assert_eq(dummy.health.hp, dummy.health.max_hp - 20)
	assert_true(dummy.status.has(StatusEffects.BURN))
	await wait_seconds(1.05)
	assert_eq(dummy.health.hp, dummy.health.max_hp - 23, "burn ticks 3")


func test_level_and_focus_raise_power_damage() -> void:
	_equip([&"fire"], 3)
	hero.power_stats.damage_bonus = 0.1
	var dummy: TrainingDummy = _dummy(Vector2(180, 100))
	input.aim = Vector2.RIGHT
	await _cast(0)
	await wait_physics_frames(25)
	# 20 * 1.4 (level 3) * 1.1 (Focus) = 30.8 -> 31
	assert_eq(dummy.health.max_hp - dummy.health.hp, 31)


func test_frost_shards_fan_out_and_freeze_up_close() -> void:
	_equip([&"frost"])
	var dummy: TrainingDummy = _dummy(Vector2(128, 100))
	input.aim = Vector2.RIGHT
	input.press(&"power_1")
	await wait_physics_frames(int(hero.balance.power_cast_time * 60.0) + 2)
	var shards: Array[Node] = world.get_children().filter(func(n: Node) -> bool: return n is PowerProjectile)
	assert_eq(shards.size(), 3)
	await wait_physics_frames(20)
	assert_eq(dummy.health.hp, dummy.health.max_hp - 30, "all three hit up close")
	assert_true(dummy.status.has(StatusEffects.FREEZE))


func test_frost_chill_slows_an_enemy() -> void:
	var sprout: Enemy = _enemy(&"sproutling", Vector2(300, 100))
	var other: Enemy = _enemy(&"sproutling", Vector2(300, 300))
	hero.position = Vector2(100, 200)
	sprout.status.apply(StatusEffects.CHILL)
	var start_a: Vector2 = sprout.position
	var start_b: Vector2 = other.position
	await wait_physics_frames(20)
	assert_lt(start_a.distance_to(sprout.position), start_b.distance_to(other.position) * 0.85)


func test_frozen_enemy_is_held_and_its_attack_cancelled() -> void:
	var sprout: Enemy = _enemy(&"sproutling", Vector2(115, 100))
	await wait_seconds(0.2)
	sprout.status.apply(StatusEffects.CHILL, 3)
	var at: Vector2 = sprout.position
	var hp: int = hero.health.hp
	await wait_seconds(1.2)
	assert_almost_eq(sprout.position.x, at.x, 0.5, "frozen in place")
	assert_eq(hero.health.hp, hp, "no bite while frozen")


func test_bulwark_blocks_then_bursts_and_staggers() -> void:
	_equip([&"stone"])
	var boar: Enemy = _enemy(&"tusk_boar", Vector2(125, 100))
	boar.ai.cooldown = 99.0
	await _cast(0)
	assert_eq(hero.health.shield, 30)
	var hp: int = hero.health.hp
	var hit: HitboxComponent = HitboxComponent.new()
	world.add_child(hit)
	var attack: AttackData = AttackData.new()
	attack.damage = 12.0
	hit.attack = attack
	hero.hurtbox.receive_hit(hit)
	assert_eq(hero.health.hp, hp, "the shield soaks it up")
	assert_eq(hero.health.shield, 18)
	assert_true(hero.state_machine.is_in(&"Move"), "a blocked hit does not stagger the hero")
	await wait_seconds(hero.balance.power_cast_time + 4.1)
	assert_eq(hero.health.shield, 0)
	assert_eq(boar.health.hp, boar.health.max_hp - 25, "the burst hits")
	assert_true(boar.status.has(StatusEffects.STUN), "and fills a regular enemy's bar")


func test_breaking_the_shield_bursts_early() -> void:
	_equip([&"stone"])
	var dummy: TrainingDummy = _dummy(Vector2(120, 100))
	await _cast(0)
	var hit: HitboxComponent = HitboxComponent.new()
	world.add_child(hit)
	var attack: AttackData = AttackData.new()
	attack.damage = 50.0
	hit.attack = attack
	hero.hurtbox.receive_hit(hit)
	assert_eq(hero.health.hp, hero.health.max_hp - 20, "30 soaked, 20 through")
	await wait_physics_frames(6)
	assert_eq(dummy.health.hp, dummy.health.max_hp - 25)


func test_bramble_roots_enemies_inside() -> void:
	_equip([&"growth"])
	var inside: Enemy = _enemy(&"sproutling", Vector2(130, 100))
	var outside: Enemy = _enemy(&"sproutling", Vector2(240, 100))
	await _cast(0)
	await wait_physics_frames(4)
	assert_true(inside.status.has(StatusEffects.ROOT))
	assert_false(outside.status.has(StatusEffects.ROOT))


func test_bramble_heals_the_hero_inside_then_withers() -> void:
	_equip([&"growth"])
	hero.health.take_damage(30)
	await _cast(0)
	await wait_seconds(2.0)
	assert_between(hero.health.hp, hero.health.max_hp - 27, hero.health.max_hp - 25, "about 2 HP a second")
	await wait_seconds(2.5)
	var patches: Array[Node] = world.get_children().filter(func(n: Node) -> bool: return n is BramblePatch)
	assert_eq(patches.size(), 0, "the patch withers")


func test_stagger_stun_interrupts_a_boss() -> void:
	var toad: Enemy = _enemy(&"mother_toad", Vector2(160, 100))
	assert_eq(toad.status.effects.stagger_max(), hero.balance.boss_stagger_bar)
	toad.status.add_stagger(hero.balance.boss_stagger_bar)
	await wait_physics_frames(2)
	assert_true(toad.status.has(StatusEffects.STUN))
	assert_eq((toad.ai as MotherToadAI).phase, MotherToadAI.Phase.IDLE)
	assert_false(toad.hitbox.active)


# --- HUD ----------------------------------------------------------------------

func test_hud_shows_power_slots_only_with_powers() -> void:
	var hud: Hud = HUD_SCENE.instantiate()
	add_child_autofree(hud)
	hud.bind_hero(hero)
	var row: Control = hud.get_node("PowerRow")
	assert_false(row.visible, "no powers, no row")
	assert_eq(hud.power_views().size(), 3)
	_equip([&"fire", &"growth"])
	assert_true(row.visible)
	await _cast(1)
	await wait_physics_frames(2)
	assert_gt(hero.powers.cooldown_fraction(1), 0.9)


func test_tuning_room_toggles_powers_within_the_slot_cap() -> void:
	var room: Node = load("res://scenes/run/tuning_room.tscn").instantiate()
	add_child_autofree(room)
	await wait_physics_frames(2)
	var room_hero: Hero = room.get_node("Actors/Hero")
	for id: StringName in PROTOTYPE_POWERS:
		room.toggle_power(id)
	TuningPanel.close()
	assert_eq(room_hero.powers.power_count(), 3, "the 4th does not fit")
	assert_true(TuningPanel.status_text.contains("full"))
	room.toggle_power(&"fire")
	TuningPanel.close()
	assert_eq(room_hero.powers.power_count(), 2)
	assert_eq(room_hero.powers.slot(0).power.id, &"frost")
