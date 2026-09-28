# Pass It On: Technical Architecture

Godot 4.7.2 (pinned), Compatibility renderer, GDScript with static typing. 2D top-down.

---

## 1. Goals

1. **Content without code.** Adding a power, villager, combo, enemy or region means adding `.tres` files, not editing scripts.
2. **Rules are testable.** Game rules (gifts, training, fusions, neighbors, renown, economy) are pure `RefCounted` classes with unit tests, independent of scenes.
3. **Multiplayer-ready.** No per-player state in global singletons; input decoupled from characters; state serializable.
4. **Fast iteration.** Any scene can be run on its own (F6) with a debug setup.

---

## 2. Project layout

```
res://
  project.godot
  addons/
    gut/                       # Godot Unit Test (added in M0)
  assets/
    sprites/ (characters/, enemies/, villagers/, effects/, ui/, tiles/)
    audio/ (music/, sfx/)
    fonts/
    shaders/ (hit_flash.gdshader, dissolve.gdshader, outline.gdshader)
  data/                        # Content Resources (.tres)
    powers/        power_fire.tres ...
    villagers/     villager_smith.tres ...
    combos/        combo_smith_fire.tres ...   (64)
    fusions/       fusion_fire_frost.tres ...  (28)
    techniques/    technique_ember_step.tres ... (64)
    weapons/       weapon_sword.tres ...
    enemies/       enemy_sproutling.tres ...
    encounters/    encounter_mossy_test.tres (waves for a room)
    regions/       region_mossy_hollow.tres ...
    buildings/     building_forge.tres ...
    trinkets/
    balance/       balance_default.tres        # all tunable numbers in one place
  scripts/
    autoload/      event_bus.gd, game_state.gd, save_manager.gd, scene_router.gd, audio_manager.gd, content_db.gd,
                   metrics.gd, debug_overlay.gd, tuning_panel.gd, debug_console.gd
    resources/     power_data.gd, villager_data.gd, combo_data.gd, fusion_data.gd, technique_data.gd,
                   weapon_data.gd, enemy_data.gd, encounter_data.gd, wave_data.gd, region_data.gd, building_data.gd, trinket_data.gd, balance_data.gd
    systems/       gift_system.gd, training_system.gd, fusion_system.gd, neighbor_system.gd,
                   renown_system.gd, progression_system.gd, economy_system.gd, run_end.gd, run_summary.gd, run_generator.gd, floor_map.gd, map_room.gd,
                   combat_math.gd, modifier_stack.gd, raid_director.gd, metrics_log.gd, metrics_report.gd, console_commands.gd
    state/         profile_state.gd, hero_state.gd, village_state.gd, villager_state.gd, run_state.gd
    components/    health_component.gd, hitbox_component.gd, hurtbox_component.gd, status_component.gd,
                   state_machine.gd, state.gd, knockback_component.gd, loot_dropper.gd,
                   input_source.gd, local_input_source.gd, telegraph_ring.gd, placeholder_shape.gd,
                   game_camera.gd, hit_flash.gd, hit_stop.gd, damage_number.gd
    abilities/     ability.gd (base), ability_ember_bolt.gd ... (one per power + fusions)
    ai/            ai_chaser.gd, ai_charger.gd, ai_ranged.gd, ai_ambusher.gd, ai_tank.gd, ai_summoner.gd ...
  scenes/
    main/          main.tscn (boot), title.tscn
    village/       village.tscn, villager.tscn, shrine.tscn, plot.tscn, gate.tscn
    run/           room.tscn (every run room, reloaded per room), room_door.gd, interact_spot.gd, pickup.gd,
                   test_room.tscn (M1 sandbox), tuning_room.tscn (feel tuning with a controller), placeholder_room.gd (checkered arena until tilesets)
    actors/        hero/ (hero.tscn, hero.gd, swing_arc.gd, states/hero_*.gd), training_dummy/,
                   enemies/*.tscn, bosses/*.tscn
    abilities/     projectiles/*.tscn, areas/*.tscn
    raid/          raid.tscn, tower.tscn, wall_segment.tscn
    ui/            hud.tscn, choice_screen.tscn, gift_ceremony.tscn, village_map.tscn, character_sheet.tscn,
                   run_map.tscn, results.tscn, codex.tscn, settings.tscn, pause.tscn
  tests/
    unit/          test_gift_system.gd, test_training_system.gd, test_fusion_system.gd, test_neighbor_system.gd,
                   test_renown_system.gd, test_progression.gd, test_combat_math.gd, test_save_roundtrip.gd,
                   test_content_integrity.gd
  tools/           check_warnings.gd (CI), metrics_report.gd (playtest gate numbers), content_validator.gd (EditorScript), csv_import.gd (optional: combos from CSV)
```

---

## 3. Autoloads

| Autoload | Responsibility | Holds per-player state? |
|---|---|---|
| `EventBus` | Global signals only (`power_given`, `villager_ranked_up`, `technique_learned`, `run_ended`, `raid_started` ...) | No |
| `ContentDB` | Loads every `.tres` under `data/` at boot, indexes by id, validates references | No |
| `GameState` | Owns the current `ProfileState` (heroes by `player_id`, and the shared village) and the `RunState` in progress (`GameState.run`, null outside runs). Loads the profile at boot, saves it after a run, and writes, loads and deletes the mid-run save | Via `ProfileState.heroes` and `RunState`, keyed by id |
| `SaveManager` | Serialize/deserialize `ProfileState` to JSON, versioned, with migrations and backup slot | No |
| `SceneRouter` | Scene transitions (fade), passes a context dictionary to the next scene | No |
| `AudioManager` | Music layers (village layering by powered villagers), SFX pools, buses | No |
| `DebugOverlay` | Debug builds only: F3 input inspector (mouse position, control under the mouse, last click and key, window focus, router state); logs clicks to Output while shown | No |
| `Metrics` | Local playtest metrics (GDD Section 17), opt-in with Playtest log on the title (`user://settings.cfg`). Listens to `EventBus` (`choice_made`, `run_summarized`, `villager_ranked_up`, `technique_learned`, `renown_changed`), adds each to the session's `MetricsLog` and rewrites `user://metrics/session_<date>T<time>.json` | No (events carry `player`) |
| `TuningPanel` | Debug builds only: pause menu for live tuning of combat feel numbers in the loaded `BalanceData` (Start in the Tuning room, F4 anywhere); Save results writes the changed lines of the `.tres`, copies a summary to the clipboard and `user://tuning_results.txt` | No |
| `DebugConsole` | Debug builds only: ` or F2 opens a command line (the game pauses); profile commands live in `ConsoleCommands`, `skip_room` and `god_mode` act on the current `RunRoom` and the heroes | No (`Hero.god_mode` is a static dev flag) |

Rule: autoloads never reference scene nodes directly (the debug-only tools above may reach into the current scene). Scenes subscribe to `EventBus` and query `GameState`.

---

## 4. Data model

### 4.1 Content resources (static, authored)
```gdscript
class_name PowerData extends Resource   # built in M3 PR 1
@export var id: StringName            # &"fire"
@export var display_name: String      # "Fire"
@export var ability_name: String      # "Ember Bolt"
@export var description: String
@export var color: Color
@export var icon_shape: StringName    # placeholder icon drawn by PowerIcon until M7
@export var ability_script: Script    # an Ability subclass (scripts/abilities/)
@export var base_cooldown: float
@export var attack: AttackData        # the hit: damage at level 1, radius, push, status, stagger
@export var level3_text: String
@export var level5_text: String
# Projectile group: projectile_count, spread_degrees, projectile_speed, projectile_range, projectile_size
# Area group: area_radius, area_duration, area_interval, shield_amount, heal_per_second
# Level 3 group (M3 PR 2): level3_attack, level3_count, level3_area_scale, level3_duration_scale
# Level 5 group (M3 PR 2): level5_attack, level5_radius, level5_duration, level5_interval, level5_spread
# Later: raid_spell_scene (M6)

class_name VillagerData extends Resource   # built in M4 PR 1
@export var id: StringName            # &"smith"
@export var display_name: String      # "Brann"
@export var job_name: String          # "Smith"
@export var workplace: String         # "Forge" (a BuildingData with levels in M6)
@export var base_service: ServiceData
@export var color: Color              # placeholder body color until sprites
@export var arrives_at_renown: int
@export var home_plot: int            # plot taken on arrival if free
@export var greeting: String
# Later: sprite_frames, visual_variants (power_id -> palette/prop overrides) in M7

class_name ComboData extends Resource     # one per villager+power (64); 16 prototype ones in M4 PR 1
@export var id: StringName            # &"smith_fire" (ComboData.id_for(villager, power))
@export var villager_id: StringName
@export var power_id: StringName
@export var novice: ServiceData
@export var adept: ServiceData
@export var technique: TechniqueData  # what a Master teaches (M5 PR 2)
@export var gift_line: String         # villager line when given the power
# Later: master_line (M5)

class_name ServiceData extends Resource  # built in M4 PR 1 (description), PR 2 (the rest)
@export var description: String
@export var modifiers: Array[ModifierData]  # stat changes applied to hero, run or village
@export var price: int                # coins to buy once per hero (0 = always on): Smith infusions
@export var shop_name: String         # "Fire infusion"
@export var sells_weapon_tiers: bool  # the Smith's base service
# Later: shop_items (meals, trinkets) when the Baker and Merchant stock need them
# only_in_raids(): every modifier is a raid.* one (Guard services until M6)

class_name ModifierData extends Resource  # built in M4 PR 2
@export var target: StringName        # see ModifierStack constants: &"hero.max_hp", &"run.flask_charges", &"income.coins", &"raid.towers"
@export var op: StringName            # &"add", &"mul"
@export var value: float
@export var condition: StringName     # optional: &"boss_room" (later &"below_30_hp" ...)

class_name TechniqueData extends Resource  # built in M5 PR 2: 16 in data/techniques/
@export var id: StringName
@export var display_name: String
@export var description: String
@export var lesson_line: String       # the Master's words in the lesson moment
@export var modifiers: Array[ModifierData]
@export var behavior_script: Script   # a TechniqueBehavior for effects that are more than stat mods (Ember Step trail)
# TechniqueBehavior (scripts/techniques/) is a Node the hero carries in run rooms
# (Hero.apply_techniques); it listens to hero signals: dodge_started, perfect_dodge,
# health changes. Prototype: Ember Step, Cold Temper, Cold Blood (13 of 16 are modifiers only).

class_name FusionData extends Resource    # one per power pair (28)
@export var power_a: StringName
@export var power_b: StringName
@export var player_name: String
@export var ability_scene: PackedScene
@export var neighbor_name: String
@export var neighbor_service: ServiceData
```

Also `WeaponData`, `EnemyData` (stats, AI script, `DropTable` drops, elite flag), `DropTable` of `DropEntry` lines (currency, chance, min, max; inline in the resource that drops them), `EventData` with `EventChoiceData` (cost, HP cost, chance, reward `DropTable`, result lines) in `data/events/`, `RegionData` (power pool, enemy pool, room weights, bosses, material, treasure drops, events, tileset, music), `BuildingData` (levels, costs, effects), `TrinketData`, `BalanceData` (every tunable number from GDD Section 15).

**Most effects are data (`ModifierData`).** Only unusual behaviors get a `behavior_script`. Target: at least 70% of combos and techniques are pure modifiers.

### 4.2 Runtime state (serializable)
```gdscript
class_name ProfileState extends RefCounted
var version: int
var season: int
var village: VillageState
var heroes: Dictionary        # player_id (int) -> HeroState ; player 0 = local owner
var codex: Dictionary         # entry_id -> bool
var run_count: int
var settings: Dictionary
var first_gift_done: bool     # the forced first gift is behind (FirstGift)
var ceremonies_seen: int      # the first gift ceremony cannot be skipped

class_name HeroState extends RefCounted
var level: int
var xp: int
var attributes: Dictionary    # &"might", &"vigor", &"focus" -> int
var weapon_mastery: Dictionary # weapon_id -> xp
var owned_weapon_tiers: Dictionary
var kept_powers: Array[KeptPower]   # max slots from balance
var techniques: Array[StringName]
var coins: int
var materials: Dictionary      # &"wood", &"ore", &"crystal" -> int
var shards: int

class_name KeptPower extends RefCounted
var power_id: StringName
var level: int
var last_leveled_run: int      # fusion tie-break

class_name VillageState extends RefCounted
var villagers: Array[VillagerState]
var plot_count: int            # 6 at the start
var buildings: Dictionary      # building_id -> level
var damaged_buildings: Array[StringName]
var renown_points: int
var runs_until_raid: int

class_name VillagerState extends RefCounted
var villager_id: StringName
var plot: int                  # the house plot they live on
var is_apprentice: bool
var power_id: StringName       # &"" if none
var training_points: int       # rank is TrainingSystem.rank(): 0 none, 1 Novice, 2 Adept, 3 Master
# technique_taught: not stored. TechniqueSystem.lessons() compares Masters with each
# hero's HeroState.techniques, so it cannot drift and every co-op hero learns (M5 PR 2).
```

`RunState` (`scripts/state/run_state.gd`) holds only the current run: region, seed, floor, `FloorMap`, current room (-1 = the floor's corridor), path, rooms cleared, time played, and per-hero carry-over (hp, flasks, the run loot `Wallet`, XP earned, damage dealt per weapon; later trinkets, fusion meter) keyed by `player_id`. It is saved at room boundaries for crash safety but is not part of long-term progression.

**Built so far (M2 PR 4):** `ProfileState` holds `run_count`, `runs_won` and `heroes` (player_id -> `HeroState`). `HeroState` holds level, XP toward the next level, unspent attribute points, attributes, weapon mastery XP and `bank` (a `Wallet` of banked coins, materials, Crystal and shards; the `coins`, `materials` and `shards` fields above are this one Wallet). Both have `to_dict()` / `from_dict()`. `RunState.to_dict()` / `from_dict(data, region)` is the mid-run save; the floor map is rebuilt from the seed, so only ids are stored. M3 PR 1: `HeroState.kept_powers` (`KeptPower`: power_id, level, last_leveled_run) in slot order, saved with the hero. M3 PR 3: `HeroState.power_offer` (power ids): the region boss's orbs until one is taken, then the taken power until it is kept, merged, given or left; saved with the hero so a quit never loses it. M4 PR 1: `ProfileState.village` (`VillageState`: `plot_count` and `villagers`, each a `VillagerState` with villager_id, plot, power_id, training_points). `VillageState.admit(roster, renown_level)` moves in villagers whose Renown level is reached (home plot if free); `GameState` calls it for a new profile and after loading, so old saves get the starting villagers. Buildings, damaged buildings, Renown and raid timing join later. M4 PR 2: `HeroState.weapon_tiers` (weapon_id -> tier bought from the Smith) and `bought_services` (combo ids of priced services), both saved; the run carry (`RunState.heroes[player_id]`) also holds `revives` (tokens left) and `clean_rooms` (fight rooms cleared in a row without a hit). `VillageState.workplace_level(id)` returns 2 until buildings (M6). M5 PR 1: `ProfileState.training_due` (training ticks the runs left waiting; `RunEnd.finish` adds one per run) and `VillageState.renown_seen` (the highest Renown level whose moment has played; saves from before Renown take their current level). M5 PR 2: `HeroState.techniques` (ids in the order taught, saved); the run carry also holds `floor` (the floor the hero was last on: a new floor refills Second Serving's `free_flasks` and heals with Second Wind) and `free_flasks`.

---

## 5. Systems (pure logic, unit tested)

| System | API sketch | Notes |
|---|---|---|
| `GiftSystem` | `can_keep(hero, power) -> bool`, `keep(hero, power)`, `give(village, hero, power, villager_idx)`, `merge(hero, power)` | Enforces slot cap, one power per villager, TP carry-over `level - 1`. Emits via returned result, callers emit `EventBus` signals. Built (M3 PR 1): `slot_count`, `find`, `can_keep`/`keep`, `can_merge`/`merge` (+1 level up to the cap), `release` (frees a slot). M3 PR 2: `level_up_cost`, `can_level_up`/`level_up` (spends banked Power Shards for +1 level; callers emit `EventBus.power_leveled`). M3 PR 3: `replace(hero, old, new)` (every slot full: the new power takes the old one's slot at level 1). M4 PR 1: `starting_tp(level)`, `can_give`, `open_villagers`, `give(village, villager_idx, power, level)`, `give_kept(village, hero, power, villager_idx)` (leaves its slot, keeps its level), `give_kept_to_make_room(village, hero, old, new, villager_idx)`. |
| `FirstGift` | `villager_index(profile, balance)`, `is_active`, `allows(profile, balance, villager_idx)`, `complete`, `settled_before` | Built (M4 PR 3): the first power must go to `BalanceData.first_gift_villager` (the Farmer). Nothing is forced if that villager is missing or holds a power. Old saves where a power was given or kept skip it. |
| `CeremonyTimeline` | `can_skip(seen, elapsed)`, `is_over`, `flight`, `swap`, `has_burst`, `shows_line` | Built (M4 PR 3): the beats of the gift ceremony (rise, fly, burst, palette swap, line) in seconds. The first ceremony cannot be skipped until its line has shown 1.5 s. |
| `PowerOffer` | `rng_for(run_seed)`, `roll(pool, hero, balance, rng)`, `take`, `is_picking`, `waiting_power`, `choice_for` (KEEP, MERGE, REPLACE, MAXED), `clear` | The region boss's reward (M3 PR 3): `boss_orb_count` different powers from `RegionData.power_pool`, seeded by the run; a kept power at the level cap is offered only when too few others are left. `RunEnd.finish` rolls it on a clear. |
| `PowerRules` | `level_multiplier`, `attack_at_level(power, level)`, `scaled_attack(attack, level)`, `has_upgrade(level, 3 or 5)`, `level_up_cost(level)`, `total_cost(level)`, `focus_damage_bonus`, `cooldown(power, focus)` | Power damage, upgrade, shard cost and cooldown math (GDD 4.1, 4.3). |
| `PowerLoadout` | `set_powers`, `slot(i)`, `is_ready`, `start_cooldown`, `cooldown_fraction`, `tick` | A hero's power slots in a fight: power, level, cooldown. The hero ticks it, the HUD draws it. |
| `StatusEffects` | `apply(id, count)`, `add_stagger`, `tick -> burn damage`, `move_scale`, `action_scale`, `is_held` | Burn, Chill/Freeze, Root, Stagger/Stun and the boss rules (GDD 7.3). `StatusComponent` wraps one per actor. |
| `TrainingSystem` | `tick(village, balance) -> Array[RankUp]` | +1 TP each powered villager, applies threshold reductions, returns rank-ups and techniques to teach. Built (M4 PR 1): `rank(villager, balance)`, `rank_for_points`, `rank_name` (thresholds `adept_tp`, `master_tp` in `BalanceData`). M5 PR 1: `tick`, `train_due(profile, balance)` (applies `ProfileState.training_due`), `preview(village, balance, ticks)` (results screen), `next_rank_points`, `progress_text` ("Novice 2/3"). A `RankUp` holds villager, power, rank before and after. Threshold reductions (Training Grounds) join in M6. |
| `FusionSystem` | `get_active_fusion(hero) -> FusionData` | Two highest-level distinct kept powers, both >= 3, tie-break by `last_leveled_run`. |
| `NeighborSystem` | `get_active_bonuses(village) -> Array[ServiceData]` | Plot adjacency graph from the village map resource; Adept+ checks; Resonance. |
| `TechniqueSystem` | `lessons(hero, village, balance, combos)`, `learn(hero, id)`, `knows`, `known(hero, all)`, `teacher(combos, id)` | Built (M5 PR 2): a Master whose Technique the hero does not know has a lesson; the village teaches it after the training tick (`Village.teach`, `EventBus.technique_learned`). `ModifierStack.collect(..., techniques)` adds the known Techniques' modifiers; the hero reads the new targets (first hit, heal on kill, flask burn, calm regen, steady, power damage and swing speed with `low_hp` / `half_hp` conditions from its own HP, thorns, chill attackers, floor heal, free flasks). |
| `RenownSystem` | `points(village, balance)`, `level_for(points, balance)`, `level`, `next_level_points`, `text`, `arrivals_at(level, roster)` | Drives villager arrivals and region unlocks. Built (M5 PR 1): points are counted from the village (`renown_per_gift` per villager holding a power, `renown_per_master` more per Master) instead of added per event, so they cannot drift; raids won and building levels join in M6. `GameState.admit_villagers()` moves in by the real level. |
| `ProgressionSystem` | `xp_for_level`, `add_xp(hero, xp, balance) -> levels`, `room_xp(type)`, `spend_point`, `respec_cost`, `can_respec`/`respec` (M4 PR 2), `max_hp`, `max_stamina`, `weapon_damage_bonus`, `mastery_level` | Formulas from `BalanceData`. `Hero.apply_progress(HeroState)` applies level, Vigor and Might at the start of every room. |
| `ModifierStack` | `collect(hero, village, balance, villagers, combos)`, `total(target, base, conditions)`, `count`, `income()`, `active_services`, `is_unlocked` | Gathers modifiers from techniques, services, neighbor bonuses, meals, trinkets; computes final stats. One place for all stat math. Built (M4 PR 2): services only; M5 PR 2 adds the hero's Techniques. Every villager's base service, plus the combo's Novice and (from Adept) Adept services; a priced service counts once bought. `total` = (base + adds) * muls, with conditions like `boss_room`. `GameState.services(player_id)` collects from ContentDB. `Hero.apply_services` reads it at the start of every room; `RunEnd.finish` banks `income()`. |
| `ShopSystem` | `next_tier`, `tier_problem`, `buy_tier`, `forge_level`, `service_problem`, `buy_service` | Built (M4 PR 2): buying from villagers with banked coins. Weapon tiers need the Forge level (`weapon_tier_forge_levels`, plus `smith.forge_bonus`) and a Master Smith from `weapon_tier_master_from`; each check returns why not ("" if it can). |
| `CombatMath` | `damage(attacker_stats, defender_stats, hit) -> DamageResult` | Crit, armor, statuses. Deterministic given an RNG seed. |
| `EconomySystem` | Costs, drops, death penalty | M2 PR 2 has the run side: `Wallet` (a hero's run loot: add, spend, spend_all, to_dict; one per `player_id` in `RunState.wallets`) and `LootRoller` (`roll(DropTable, rng)`, `split_piles`, `rng_for(run_seed, floor, room, salt)`). M2 PR 4: `kept_amount(amount, fraction)` and `bank_run_loot(run_wallet, bank, fraction)`. |
| `RunEnd` | `finish(run, profile, success, balance) -> {player_id: RunSummary}` | Closes a run for every hero in it: adds XP (level-ups), weapon mastery, banks loot (all on a clear, `death_keep_fraction` on a fall), counts the run. `RunSummary` is what the results screen shows. |
| `EventResolver` | `can_choose(choice, wallet)`, `resolve(choice, wallet, hp, max_hp, rng) -> EventOutcome` | Event rooms: pay the cost first (an HP cost never kills), then roll success and the reward. Rewards are returned so the room drops them as pickups. |
| `RunGenerator` | `generate_floor(region, floor_idx, seed) -> FloorMap`, `pick_encounter(region, map, room, seed)`, `pick_event(region, map, room, seed)` | Seeded RNG so co-op peers and daily runs can reproduce maps. A `FloorMap` holds rows of `MapRoom`s (type, lane, links to the next row) and one exit room. Rules in GDD 6.1. |
| `RaidDirector` | Wave composition from run count and faction | |

All randomness uses a `RandomNumberGenerator` passed in with an explicit seed. No `randi()` globals in systems.

---

## 6. Scene flow

```
main.tscn (boot: ContentDB load, SaveManager load)
  -> title.tscn
  -> village.tscn  <------------------------------+
       gate -> room.tscn (corridor, then rooms)   |
                -> results.tscn                    |
                -> choice_screen.tscn (+ ceremony) |
                -> training tick (in village) -----+
       every 4th run -> raid.tscn -> village.tscn
```

`SceneRouter.go(scene_path, context: Dictionary)` handles fades and passes context (region id, seed, results).

**Runs (M2):** starting a run puts a `RunState` in `GameState.run`. `room.tscn` (`RunRoom`) reads it and builds the current room: the floor's safe corridor, a fight (`WaveDirector` with the encounter from `RunGenerator.pick_encounter`, a seeded pillar layout), a Rest room, or a signpost for room types not built yet. When the room is done, doors in the top wall open, one per next room, left to right in map lane order, each signed with its room type. Walking into a door saves the hero's HP and flasks to the `RunState`, moves it, and reloads `room.tscn`. The floor exit opens stairs to the next floor's corridor. Every room saves the run as it loads (mid-run save). A cleared fight adds XP to the run; hero hits add weapon damage. When the region boss falls, or the hero does, `RunEnd.finish` banks the run at once, the profile is saved, the run save is deleted, and `results.tscn` (`ResultsScreen`) opens with the `RunSummary` in the router context. After a clear the boss room shows the power orbs (`InteractSpot`s of kind `power_orb`); the hero takes one first. Results then continue to the village (`village.tscn`, M4 PR 1), where the Shrine glows while `HeroState.power_offer` is not empty and opens `choice_screen.tscn` (`ChoiceScreen`): take an orb if none was taken, then Keep, Merge, Give to a villager, give a kept power away to make room (full slots), or leave it. The Choice screen returns to the village with `{"from": "shrine"}` (the hero stands below the Shrine); after a gift it also passes `"ceremony"` (villager, power, first gift), and the village plays `GiftCeremony` (`scenes/ui/gift_ceremony.tscn`, M4 PR 3): bars, a Spark flying from the hero to the villager, a particle burst, the villager's palette swap (`Villager.gift_blend`) and roof trim (`VillagePlot.trim_blend`), then the villager's line and new service. The camera follows its `focus`, the hero stands still, and `EventBus.gift_ceremony_finished` fires at the end. Once nothing waits at the Shrine (on arrival, or after the ceremony), `Village.grow()` applies `TrainingSystem.train_due`, moves in the villagers a new Renown level brings, saves, and queues a `VillageMoment` (`scenes/ui/village_moment.gd`, code-built) for every rank-up (the villager's `rank_blend` and the plot's pennant grow in) and every new Renown level (the newcomer fades in); `EventBus.villager_ranked_up` and `renown_changed` fire. The gate stays shut while a power waits at the Shrine. While `FirstGift` is active the Choice screen only offers giving to that villager. The title's New game (second press) starts a fresh profile, first gift included. The Choice screen's Grow stronger view (`GrowthPanel`, M4 PR 2) spends attribute points and shards and resets attributes (the results screen only says what waits). Each run room calls `Hero.apply_progress` then `Hero.apply_services(GameState.services(player_id), conditions)` (boss rooms add `boss_room`), then restores the carry: HP, flasks, revive tokens, clean rooms. A lethal hit uses a revive token (`Hero.try_revive`, `EventBus.hero_revived`) before `hero_died`. The title goes to the village (its line says when a power waits at the Shrine); the village gate starts a run or continues the saved one. Esc is Save and quit: the title then shows Continue run. `RunMap` (`scenes/ui/run_map.tscn`) draws the floor map; the Map action toggles it. Playing `room.tscn` alone (F6) starts a test run.

---

## 7. Actors and combat

- **Hero** (`hero/hero.tscn`): `CharacterBody2D` + components. States (child nodes of `StateMachine`, one script each in `hero/states/`): Move (includes idle), Attack (one node, re-entered per combo step), Dodge, Drink, Cast (a power's short wind-up), Hurt, Dead. The hero calls `state_machine.physics_update()` from its own `_physics_process` so input buffering, stamina and i-frames update first. Input comes from an `InputSource` child (see 9); if none is present the hero adds a `LocalInputSource`. Tests drive the hero with the scripted base `InputSource`.
- **Attacks** are `AttackData` resources (damage, wind-up, active, recovery, reach, radius, lunge, knockback, hit-stop, shake). Weapons hold a combo of them; enemies will use the same resource. `CombatStats` carries the numbers `CombatMath` needs for each side.
- **Damage flow:** an active `HitboxComponent` checks overlapping `HurtboxComponent`s each physics frame and hits each once per `activate()`. The hurtbox runs `CombatMath`, applies the result to its `HealthComponent` and emits `hurt(result, hitbox)`; the hitbox emits `hit_landed`. The victim spawns its own damage number and flash.
- **Enemies:** one scene (`actors/enemy/enemy.tscn`, `Enemy`) + components + an `EnemyAI` script (`scripts/ai/`: `SwarmAI`, `ChargerAI`, `RangedAI`, `SummonerAI`) chosen by `EnemyData.ai_script`. The AI is a `RefCounted` phase machine that calls the enemy's verbs (move, face, telegraph, attack, shoot, drop a hazard, summon). Telegraphs use `TelegraphRing` (a ring for areas, a lane for charges and shots, a ring on the floor for a lobbed cloud) and emit `telegraph_started`. Splitting (`split_into`, `split_count`) and summoning both spawn children and emit `spawned`, so the `WaveDirector` counts them. `ChargerAI` chains `charge_chain` charges (Elder Boar). `WaveDirector.enemy_died` lets the room drop each enemy's loot before a clear.
- **Bosses** use the same enemy scene. Their data is `BossData` (extends `EnemyData`: move order, enrage line, and the numbers for each move: leap, tongue, volley, root walls, close attack). `BossAI` (base) plays the moves from a `BossPattern` (pure, tested: the order repeats, enrage switches once) and calls `Enemy.announce_enrage()`; `MotherToadAI` and `WardenAI` are the two bosses so far. Boss verbs on `Enemy`: `lash` (a reaching hitbox drawn as a tongue), `set_airborne` (no body or hurtbox while leaping), `telegraph_lines` (a fan of lanes), `raise_root_wall` (`RootWall`, a `StaticBody2D` on the world layer that outlines, bursts, blocks and withers with its maker). `WaveDirector.enemy_spawned` lets the room give a boss the HUD's boss bar.
- **Run rooms:** `InteractSpot` (stand on it, press Interact) is every offer: rest comforts, the chest, merchant wares, event choices. `Pickup` (a `Node2D`, no physics) drifts to a nearby hero, is collected by distance and reports `collected`; the room adds it to that hero's `Wallet`.
- **Waves:** `EncounterData` holds `WaveData` lists. `WaveDirector` (in the room) shows spawn markers, spawns enemies, tracks splits and emits `wave_started`, `wave_cleared`, `room_cleared` (also on `EventBus`). The clear rules live in `WaveTracker` (pure, tested).
- **Hitboxes and hurtboxes** use collision layers:

| Layer | Use |
|---|---|
| 1 | World |
| 2 | Hero body |
| 3 | Enemy body |
| 4 | Hero hitbox |
| 5 | Enemy hitbox |
| 6 | Hero hurtbox |
| 7 | Enemy hurtbox |
| 8 | Pickups |
| 9 | Buildings (raids) |

- **Abilities:** `PowerData.ability_script` names an `Ability` (`scripts/abilities/`, a `RefCounted` with `cast(hero, power, level, aim)`), made fresh per cast by `Hero.cast_power`. It reads every number from the `PowerData`, scales damage with `PowerRules`, and spawns effect scenes from `scenes/abilities/`: `PowerProjectile` (bolts, shards), `PowerBurst` (a ring hit), `PowerPatch` (a lingering area: status pulses, an optional damage hit, heal, spread; Bramble and Fire's burning ground), `StoneShield` (a shield on the hero using `HealthComponent.shield`; emits `burst`, and with `reflects` turns `ThornArrow`s in the `enemy_projectiles` group back as hero hits). Level 3 and 5 upgrades are in the same Ability script (`PowerRules.has_upgrade`); their numbers are `PowerData.level3_*` and `level5_*` (an extra `AttackData` each plus a few sizes and times), so tuning an upgrade is data only. Power hitboxes use `Hero.power_stats` (crit and Focus, no weapon tier), so power damage never counts toward weapon mastery. Kept powers reach the hero through `Hero.apply_progress` -> `equip_powers(kept_powers)` -> `PowerLoadout`; the HUD shows one `PowerSlotView` per slot.
- **Statuses:** a hit's `AttackData` can carry `status`, `status_stacks` and `stagger`; `HurtboxComponent.receive_hit` passes them to its linked `StatusComponent` (`receive_status` does it without damage, for areas). `StatusComponent` ticks a pure `StatusEffects`, deals burn damage to its `HealthComponent` and emits `burned` and `staggered`. `Enemy` scales its AI clock by `action_scale()` (chill), its own movement by `move_scale()` (chill, root), and holds the AI while frozen or stunned (`EnemyAI.interrupt()` once, `can_be_held()` lets Mother Toad finish a leap). `StatusBadge` draws pips and the stagger bar.
- **Game feel:** hit-stop (`HitStop.request()`, an `Engine.time_scale` pulse; the newest request restores speed, and `HitStop.enabled` is the accessibility toggle), hit flash shader (`assets/shaders/hit_flash.gdshader`, material local to scene), screen shake (`GameCamera` listens to `EventBus.camera_shake_requested(trauma)`), damage numbers (`DamageNumber.spawn()`).

---

## 8. Village

- **Built so far (M4 PR 1):** `village.tscn` (`Village`): a placeholder ground (`PlaceholderRoom`, 30x17 tiles) with 6 `VillagePlot`s (index, draws the resident's house in their color, with the workplace sign; a gift trims the roof in the power's color; houses block like walls), one `Villager` (`villager.tscn`: placeholder body, name and rank at the feet, a glow and icon in the power's color, an `InteractSpot` without a ring to talk) in front of each lived-in plot, and `InteractSpot`s for the Shrine (opens the Choice screen), the gate (starts or continues a run) and the notice board (village news until raid warnings in M6). The hero walks it with the combat controls; Esc goes to the title. M4 PR 2: talking to a villager who sells something (`ShopPanel.sells_anything`: weapon tiers, or a priced combo service) opens a `ShopPanel` on the overlay (code-built, no scene); the hero stands still until it closes. Buying saves the profile and emits `EventBus.village_purchase`.
- Tile-based map (`TileMapLayer`) with **plot** nodes; plot adjacency defined in a `VillageLayoutData` resource (list of plot ids and edges) so `NeighborSystem` can use it without scenes.
- Villager visuals update from `VillagerState` (power palette swap via shader uniform, prop sprites per rank).
- Village music layers: `AudioManager` enables one stem per powered villager.

---

## 9. Multiplayer readiness (build now, use later)

1. **Player ids everywhere.** `GameState.profile.heroes[player_id]`. Local single player uses id 0.
2. **Input abstraction.** Hero reads from an `InputSource` child (`LocalInputSource`, later `NetworkInputSource`, `DeviceInputSource` for local co-op by device id).
3. **Seeded generation.** Floor maps and loot rolls are seeded so peers agree.
4. **Authority model (planned):** host-authoritative. Host runs enemies and room state; clients send inputs and predict their own hero. Use Godot's `MultiplayerSpawner` and `MultiplayerSynchronizer` for actors.
5. **Serializable snapshots.** `VillageState` exports to a compact JSON "village snapshot" for async visits and raid help.
6. **No gameplay logic in UI scripts.** UI calls systems; systems are peer-agnostic.

Transport decision (ENet vs Steam networking) is deferred to M10 (see MEMORY.md Open questions).

---

## 10. Save system

- **Controls:** `InputBindings` (`scripts/systems/input_bindings.gd`, pure static rules) rebinds the InputMap, swaps on conflicts, names inputs for hints, and saves one keyboard and one gamepad input per action to `user://settings.cfg` (section `input`). `main.gd` applies it at boot. The menu is `scenes/ui/controls_menu.tscn`. Machine settings live here, not in the profile save.

- Location: `user://saves/slot_N.json`, plus `slot_N.bak` written before each save.
- Format: JSON with `version`. `SaveManager` runs migrations `v1 -> v2 -> ...` on load.
- Save points: after the Choice, after the training tick, after raids, on quit. Mid-run: `run_slot_N.json` at room boundaries.
- Built so far (M2 PR 4): `main.gd` loads slot 0 into `GameState.profile` at boot (a fresh profile if none). The profile is saved when a run ends and when attribute points are spent on the results screen. Each run room writes `run_slot_0.json` as it loads. Save and quit rewrites that entry save with HP and flasks lowered to what the hero has at that moment (never raised), so quitting cannot heal the hero or keep loot from a room that starts over. A cleared or fallen run deletes the run save before the results screen, so a fall cannot be undone by quitting. A run save that no longer fits the content (unknown region, missing room) is deleted instead of blocking the title.
- Round-trip unit test for every state class.

---

## 11. Testing and CI

- **GUT** unit tests for all systems and a **content integrity test** that:
  - every villager x power pair has exactly one `ComboData` (64),
  - every power pair has exactly one `FusionData` (28),
  - every combo references an existing technique,
  - no duplicate ids.
- Run locally: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`.
- **Warnings check:** `tools/check_warnings.gd` compiles every project script (addons excluded) with warnings raised to errors, via a temporary `override.cfg`. Signals on `EventBus` are exempt from the unused-signal warning (`@warning_ignore_start`) because other scripts emit them.
- **CI (GitHub Actions, M0):** download Godot headless, import the project, check warnings, run GUT, fail on any error.
- **Playtest builds (M5):** `.github/workflows/build.yml` (run by hand, or on a `v*` tag, which also makes a GitHub release) exports the `export_presets.cfg` presets (Windows Desktop and Linux, release, PCK embedded; tests, tools, docs and GUT left out), boots the Linux build headless, and zips each with `docs/PLAYTEST.md` as its README. macOS waits for signing.
- Debug tools (dev builds only): F3 input inspector (`DebugOverlay`, added for the title click report); tuning menu (`TuningPanel`, opened with Start in the Tuning room or F4 anywhere, pauses the game: D-pad or arrows pick and change a number, RB or Shift for 5x, X or Backspace resets, A or Enter runs Save results / Reset all / room actions, B or Start closes); debug console (`DebugConsole`, ` or F2, pauses the game) with `give_power fire` (the power waits at the Shrine), `set_tp smith 7`, `add_renown 10` (`VillageState.bonus_renown`, saved), `skip_room`, `god_mode` and `help`; in the village, closing it shows the village again so rank-ups, lessons and Renown moments play.
- **Metrics (M5):** see `Metrics` in Section 3. `MetricsLog` builds the records, `MetricsReport` sums sessions into the prototype gate numbers; `godot --headless -s tools/metrics_report.gd -- <folder>` prints them.

---

## 12. Performance budget

- 60 FPS on Steam Deck. Max ~80 enemies and ~300 projectiles on screen in raids.
- Object pools for projectiles, damage numbers and particles.
- Avoid per-frame allocations in combat; stats recomputed only when modifiers change (dirty flag in `ModifierStack`).

---

## 13. Content pipeline

- Designers can author combos in a spreadsheet (`tools/combos.csv`) and run `tools/csv_import.gd` (EditorScript) to generate/update `data/combos/*.tres`. Optional, added in M8 when volume matters.
- `tools/content_validator.gd` runs the same checks as the integrity test inside the editor.

---

## 14. Localization

- All player-facing strings through `tr()` with keys (`POWER_FIRE_NAME`, `COMBO_SMITH_FIRE_NOVICE`). CSV translation files in `localization/`. English only until M12.
