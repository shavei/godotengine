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
    regions/       region_mossy_hollow.tres ...
    buildings/     building_forge.tres ...
    trinkets/
    balance/       balance_default.tres        # all tunable numbers in one place
  scripts/
    autoload/      event_bus.gd, game_state.gd, save_manager.gd, scene_router.gd, audio_manager.gd, content_db.gd
    resources/     power_data.gd, villager_data.gd, combo_data.gd, fusion_data.gd, technique_data.gd,
                   weapon_data.gd, enemy_data.gd, region_data.gd, building_data.gd, trinket_data.gd, balance_data.gd
    systems/       gift_system.gd, training_system.gd, fusion_system.gd, neighbor_system.gd,
                   renown_system.gd, progression_system.gd, economy_system.gd, run_generator.gd,
                   combat_math.gd, modifier_stack.gd, raid_director.gd
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
    run/           run.tscn, floor_map.tscn, room.tscn, rooms/*.tscn, corridor.tscn,
                   test_room.tscn (M1 sandbox), placeholder_room.gd (checkered arena until tilesets)
    actors/        hero/ (hero.tscn, hero.gd, swing_arc.gd, states/hero_*.gd), training_dummy/,
                   enemies/*.tscn, bosses/*.tscn
    abilities/     projectiles/*.tscn, areas/*.tscn
    raid/          raid.tscn, tower.tscn, wall_segment.tscn
    ui/            hud.tscn, choice_screen.tscn, gift_ceremony.tscn, village_map.tscn, character_sheet.tscn,
                   run_map_ui.tscn, results.tscn, codex.tscn, settings.tscn, pause.tscn
  tests/
    unit/          test_gift_system.gd, test_training_system.gd, test_fusion_system.gd, test_neighbor_system.gd,
                   test_renown_system.gd, test_progression.gd, test_combat_math.gd, test_save_roundtrip.gd,
                   test_content_integrity.gd
  tools/           check_warnings.gd (CI), content_validator.gd (EditorScript), csv_import.gd (optional: combos from CSV)
```

---

## 3. Autoloads

| Autoload | Responsibility | Holds per-player state? |
|---|---|---|
| `EventBus` | Global signals only (`power_given`, `villager_ranked_up`, `technique_learned`, `run_ended`, `raid_started` ...) | No |
| `ContentDB` | Loads every `.tres` under `data/` at boot, indexes by id, validates references | No |
| `GameState` | Owns the current `ProfileState` (village + heroes by `player_id`) | Via `ProfileState`, keyed by id |
| `SaveManager` | Serialize/deserialize `ProfileState` to JSON, versioned, with migrations and backup slot | No |
| `SceneRouter` | Scene transitions (fade), passes a context dictionary to the next scene | No |
| `AudioManager` | Music layers (village layering by powered villagers), SFX pools, buses | No |
| `DebugOverlay` | Debug builds only: F3 input inspector (mouse position, control under the mouse, last click and key, window focus, router state); logs clicks to Output while shown | No |

Rule: autoloads never reference scene nodes directly. Scenes subscribe to `EventBus` and query `GameState`.

---

## 4. Data model

### 4.1 Content resources (static, authored)
```gdscript
class_name PowerData extends Resource
@export var id: StringName            # &"fire"
@export var display_name: String
@export var color: Color
@export var icon: Texture2D
@export var ability_scene: PackedScene
@export var base_cooldown: float
@export var base_damage: float
@export var status: StringName        # &"burn"
@export var level3_text: String
@export var level5_text: String
@export var raid_spell_scene: PackedScene

class_name VillagerData extends Resource
@export var id: StringName            # &"smith"
@export var display_name: String
@export var job_name: String
@export var base_service: ServiceData
@export var workplace: BuildingData
@export var arrives_at_renown: int
@export var sprite_frames: SpriteFrames
@export var visual_variants: Dictionary   # power_id -> palette/prop overrides

class_name ComboData extends Resource     # one per villager+power (64)
@export var villager_id: StringName
@export var power_id: StringName
@export var novice: ServiceData
@export var adept: ServiceData
@export var technique: TechniqueData
@export var gift_line: String         # villager line at the ceremony
@export var master_line: String

class_name ServiceData extends Resource
@export var description: String
@export var modifiers: Array[ModifierData]  # stat changes applied to hero, run or village
@export var shop_items: Array[Resource]

class_name ModifierData extends Resource
@export var target: StringName        # &"hero.max_hp", &"run.flask_charges", &"village.building_cost"
@export var op: StringName            # &"add", &"mul"
@export var value: float
@export var condition: StringName     # optional, &"boss_floor", &"below_30_hp" ...

class_name TechniqueData extends Resource
@export var id: StringName
@export var display_name: String
@export var description: String
@export var modifiers: Array[ModifierData]
@export var behavior_script: Script   # for effects that are more than stat mods (Ember Step trail)

class_name FusionData extends Resource    # one per power pair (28)
@export var power_a: StringName
@export var power_b: StringName
@export var player_name: String
@export var ability_scene: PackedScene
@export var neighbor_name: String
@export var neighbor_service: ServiceData
```

Also `WeaponData`, `EnemyData` (stats, AI script, drops), `RegionData` (power pool, enemy pool, room weights, bosses, tileset, music), `BuildingData` (levels, costs, effects), `TrinketData`, `BalanceData` (every tunable number from GDD Section 15).

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
var plots: Dictionary          # plot_id -> villager index or -1
var buildings: Dictionary      # building_id -> level
var damaged_buildings: Array[StringName]
var renown_points: int
var runs_until_raid: int

class_name VillagerState extends RefCounted
var villager_id: StringName
var is_apprentice: bool
var power_id: StringName       # &"" if none
var training_points: int
var rank: int                  # 0 none, 1 Novice, 2 Adept, 3 Master
var technique_taught: bool
```

`RunState` holds only the current run (map, room index, hp, flasks, trinkets, fusion meter). It is saved at room boundaries for crash safety but is not part of long-term progression.

---

## 5. Systems (pure logic, unit tested)

| System | API sketch | Notes |
|---|---|---|
| `GiftSystem` | `can_keep(hero, power) -> bool`, `keep(hero, power)`, `give(village, hero, power, villager_idx)`, `merge(hero, power)` | Enforces slot cap, one power per villager, TP carry-over `level - 1`. Emits via returned result, callers emit `EventBus` signals. |
| `TrainingSystem` | `tick(village, balance) -> Array[RankUpEvent]` | +1 TP each powered villager, applies threshold reductions, returns rank-ups and techniques to teach. |
| `FusionSystem` | `get_active_fusion(hero) -> FusionData` | Two highest-level distinct kept powers, both >= 3, tie-break by `last_leveled_run`. |
| `NeighborSystem` | `get_active_bonuses(village) -> Array[ServiceData]` | Plot adjacency graph from the village map resource; Adept+ checks; Resonance. |
| `RenownSystem` | `add(village, reason)`, `level_for(points)`, `new_unlocks(before, after)` | Drives villager arrivals and region unlocks. |
| `ProgressionSystem` | XP curve, level-ups, attribute points, mastery curve | Formulas from `BalanceData`. |
| `ModifierStack` | `collect(hero, village, run) -> Stats` | Gathers modifiers from techniques, services, neighbor bonuses, meals, trinkets; computes final stats. One place for all stat math. |
| `CombatMath` | `damage(attacker_stats, defender_stats, hit) -> DamageResult` | Crit, armor, statuses. Deterministic given an RNG seed. |
| `EconomySystem` | Costs, drops, death penalty | |
| `RunGenerator` | `generate_floor(region, floor_idx, seed) -> FloorMap` | Seeded RNG so co-op peers and daily runs can reproduce maps. |
| `RaidDirector` | Wave composition from run count and faction | |

All randomness uses a `RandomNumberGenerator` passed in with an explicit seed. No `randi()` globals in systems.

---

## 6. Scene flow

```
main.tscn (boot: ContentDB load, SaveManager load)
  -> title.tscn
  -> village.tscn  <------------------------------+
       gate -> run.tscn (floor_map -> rooms)      |
                -> results.tscn                    |
                -> choice_screen.tscn (+ ceremony) |
                -> training tick (in village) -----+
       every 4th run -> raid.tscn -> village.tscn
```

`SceneRouter.go(scene_path, context: Dictionary)` handles fades and passes context (region id, seed, results).

---

## 7. Actors and combat

- **Hero** (`hero/hero.tscn`): `CharacterBody2D` + components. States (child nodes of `StateMachine`, one script each in `hero/states/`): Move (includes idle), Attack (one node, re-entered per combo step), Dodge, Drink, Hurt, Dead; Cast arrives with powers in M3. The hero calls `state_machine.physics_update()` from its own `_physics_process` so input buffering, stamina and i-frames update first. Input comes from an `InputSource` child (see 9); if none is present the hero adds a `LocalInputSource`. Tests drive the hero with the scripted base `InputSource`.
- **Attacks** are `AttackData` resources (damage, wind-up, active, recovery, reach, radius, lunge, knockback, hit-stop, shake). Weapons hold a combo of them; enemies will use the same resource. `CombatStats` carries the numbers `CombatMath` needs for each side.
- **Damage flow:** an active `HitboxComponent` checks overlapping `HurtboxComponent`s each physics frame and hits each once per `activate()`. The hurtbox runs `CombatMath`, applies the result to its `HealthComponent` and emits `hurt(result, hitbox)`; the hitbox emits `hit_landed`. The victim spawns its own damage number and flash.
- **Enemies:** `CharacterBody2D` + components + an AI script chosen by `EnemyData`. Telegraphs are `AnimationPlayer` tracks with a `telegraph_started` signal for the attack warning VFX.
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

- **Abilities:** each power ability is a scene with an `Ability` script (`cast(caster, aim_dir, level)`), reading numbers from `PowerData` and the hero's `Stats`.
- **Game feel:** hit-stop (`HitStop.request()`, an `Engine.time_scale` pulse; the newest request restores speed, and `HitStop.enabled` is the accessibility toggle), hit flash shader (`assets/shaders/hit_flash.gdshader`, material local to scene), screen shake (`GameCamera` listens to `EventBus.camera_shake_requested(trauma)`), damage numbers (`DamageNumber.spawn()`).

---

## 8. Village

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

- Location: `user://saves/slot_N.json`, plus `slot_N.bak` written before each save.
- Format: JSON with `version`. `SaveManager` runs migrations `v1 -> v2 -> ...` on load.
- Save points: after the Choice, after the training tick, after raids, on quit. Mid-run: `run_slot_N.json` at room boundaries.
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
- **CI (GitHub Actions, M0):** download Godot headless, import the project, check warnings, run GUT, fail on any error. Later: export builds for Windows, Linux, macOS on tags.
- Debug tools (dev builds only): F3 input inspector (`DebugOverlay`, added for the title click report); console commands `give_power fire`, `set_tp smith 7`, `add_renown 10`, `skip_room`, `god_mode`.

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
