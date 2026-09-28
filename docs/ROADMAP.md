# Pass It On: Roadmap

Milestones are sequential. Each has tasks, a **Done when** checklist, and (where relevant) playtest questions. Estimates assume one developer working part time with Claude; adjust as real velocity becomes clear.

Legend: `[ ]` todo, `[x]` done. Update this file as work lands, and log decisions in `MEMORY.md`.

| Milestone | Goal | Estimate |
|---|---|---|
| M0 | Project setup | 2 to 3 days |
| M1 | Combat core | 2 weeks |
| M2 | Run structure | 1.5 weeks |
| M3 | Kept powers | 1.5 weeks |
| M4 | Village and the Choice | 2 weeks |
| M5 | Training and Techniques (**prototype gate**) | 1.5 weeks |
| M6 | Raids, Neighbors, Fusions | 2 weeks |
| M7 | Vertical slice | 4 weeks |
| M8 | Content expansion | 8 to 10 weeks |
| M9 | Story, endgame, Codex | 4 weeks |
| M10 | Local co-op | 3 weeks |
| M11 | Online co-op, village visits, raid help | 6 weeks |
| M12 | Polish and release | 6+ weeks |

---

## M0: Project setup
- [x] Create Godot 4.7.2 project (`project.godot`) at repo root: 640x360 viewport, `canvas_items` stretch, integer scaling, nearest filter, Compatibility renderer.
- [x] Folder structure from `docs/ARCHITECTURE.md` Section 2.
- [x] `.gitignore` for Godot (`.godot/`, builds), `.gitattributes` for line endings and binary assets.
- [x] Input map (GDD Section 7.1) for gamepad and keyboard/mouse.
- [x] Autoloads: `EventBus`, `ContentDB`, `GameState`, `SaveManager` (JSON, backup, migration hook), `SceneRouter` (fades, context), `AudioManager`.
- [x] Install GUT 9.7.1, unit tests for project settings, input map, save manager, content DB, scenes.
- [x] GitHub Actions workflow: headless import, GUT run, boot check.
- [x] Collision layer names (ARCHITECTURE Section 7).
- [x] Boot scene hands off to a placeholder title screen.
- Placeholder art: colored rectangles and circles are fine until M7.

**Done when:** project opens with no errors, `main.tscn` boots to an empty title screen, CI is green.

## M1: Combat core
Split into small PRs, each playable: (1) hero combat core in a test room with training dummies, (2) enemies, waves and room clear, (3) remaining game feel and tuning.

- [x] Hero: movement (8-direction, acceleration), aim, 3-hit sword combo, dodge with i-frames and stamina.
- [x] Components: Health, Hitbox, Hurtbox, Status, Knockback, StateMachine (plus InputSource for multiplayer readiness).
- [x] `CombatMath` + unit tests (damage formula, crit, armor cap).
- [x] 3 enemies from Mossy Hollow: Sproutling (swarm), Tusk Boar (charger), Thorn Archer (ranged), with telegraphs.
- [x] Test room scene with waves; room clear detection. (Wave room with 3 waves; the dummy test room stays for practice.)
- [x] Game feel: hit flash, hit-stop, screen shake, damage numbers, death animations.
- [x] HUD: HP, stamina.
- [x] Flasks (3 charges).
- [x] Gamepad feel: stick aim assist for melee, rumble, low stamina cue. F4 live tuning panel for the owner's playtests.
- [x] Tuning room on the title: controller-driven tuning menu, Save results writes `balance_default.tres` for a GitHub Desktop commit.
- [x] Owner playtest with a gamepad: tune in the Tuning room and confirm the done criteria below.
- Perfect dodge (GDD 7.2) waits for the Fusion meter (M6); only the slow-motion part could come earlier if playtests ask for it.

**Done when:** a 3-wave room is fun to play for 5 minutes with placeholder art. Dodge feels responsive (tested with gamepad).

---

## M2: Run structure
Split into small PRs, each playable: (1) floor maps, doors and the room flow, (2) drops, pickups and the other room types, (3) Mother Toad and the Warden of Roots, (4) XP, results, death rules and mid-run save.

- [x] `RegionData` for Mossy Hollow; room weights.
- [x] `RunGenerator`: seeded branching node map per floor (5 to 7 deep), unit tested (connectivity, room type distribution).
- [x] Floor map UI; door previews of room type.
- [x] Room types: Combat, Elite, Treasure, Rest, Merchant (basic), Event (2 sample events). (PR 2: Elder Boar and Spore Witch elites, treasure chest, merchant with flask, heal and shard, Mossy Shrine and Wishing Well events. Trinkets join the merchant in M8.)
- [x] Mini-boss (Mother Toad) and region boss (Warden of Roots, phase 1 only for now). (PR 3: `BossData`, `BossPattern`, boss bar, root walls; both bosses also in the Tuning room menu.)
- [x] Coins, Wood, Crystal, Power Shards drops and pickups. (Run wallet per hero; banking at run end is PR 4.)
- [x] Results screen; death handling (50% materials rule). (PR 4: `RunEnd` banks the run, `results.tscn` shows XP, mastery and loot found vs kept.)
- [x] `ProgressionSystem`: XP, level-ups, attribute points (unit tested). (PR 4: points are spent on the results screen; Focus locked until M3; weapon mastery tallied too.)
- [x] Mid-run save at room boundaries. (PR 4: `run_slot_0.json` on every room load, Save and quit on Esc, Continue run on the title.)
- [x] Owner plays a full run start to finish and checks the done criteria below (time on the results screen).

**Done when:** a full 3-floor run can be played start to finish in 12 to 15 minutes and ends at a results screen.

---

## M3: Kept powers
Split into small PRs, each playable: (1) powers, abilities (level 1), statuses, HUD slots, keep and merge rules (try them in the Tuning room), (2) level 3 and 5 upgrades, Power Shard costs and leveling on the results screen, Focus unlocked, (3) boss reward orbs and the keep screen, so runs earn powers.

- [x] `PowerData` resources for Fire, Frost, Growth, Stone [P].
- [x] Ability base class and 4 abilities with levels 1, 3, 5 behaviors. (Level 1 in PR 1, levels 3 and 5 in PR 2.)
- [x] Status effects: Burn, Chill/Freeze, Root, Stagger (+ boss rules).
- [x] 3 power slots on the HUD with cooldowns.
- [x] Power Shards spending UI (level up at the Shrine or run end). (Results screen in PR 2; the Shrine joins in M4.)
- [x] Boss reward: 2 power orbs, pick 1. (PR 3: orbs in the boss room, then the keep screen after the results: Keep, Merge, let a kept power go, or Leave. Give joins in M4.)
- [ ] Owner plays full runs, earns powers and checks the done criteria below.
- [x] `GiftSystem.keep` and `merge` with unit tests (slot cap, merge level-up).

**Done when:** you can earn powers from bosses, keep up to 3, level them with shards, and they feel distinct in combat.

---

## M4: Village and the Choice
Split into small PRs, each playable: (1) villagers, combos, the village scene and the Give flow, so the loop Village > Run > Results > Shrine > Village works and saves, (2) services that change runs (`ModifierStack`: Farmer flasks, Healer revive tokens, Smith shop, Guard raid stub) and the Shrine's leveling and attribute points, (3) gift ceremony and the forced first gift tutorial.

- [x] Village scene: tilemap, 6 plots, Shrine, gate, notice board. (PR 1: placeholder ground and houses until M7 tilesets; the notice board has no raids to show until M6.)
- [x] Villagers [P]: Smith, Farmer, Guard, Healer with base services. (PR 1: data, houses, talking. Services change runs in PR 2. The Healer lives there from the start until Renown lands in M5.)
- [x] `ComboData` for the 16 prototype combos (Novice and Adept services; Techniques stubbed). (Technique name and text only; `TechniqueData` in M5.)
- [x] `ModifierStack` gathering services into hero and run stats (unit tested). (PR 2: services only; Techniques, Neighbors, meals and trinkets join the same stack later.)
- [x] Choice screen: Keep / Give / Merge, villager preview cards, slot-full flow. (PR 1: Give with a second press, full slots give a kept power away to make room, and the Shrine gives kept powers away at any time.)
- [x] `GiftSystem.give` with TP carry-over (unit tested).
- [x] Gift ceremony (simple version: particles, villager palette swap, line of dialogue). (PR 3: plays in the village after every gift: bars, the Spark flies from the hero to the villager and bursts, their clothes and roof take the power's color, then their line and new service. 7.5 s; the first cannot be skipped until its line is read.)
- [x] Smith shop (weapon tiers, infusions), Farmer flasks, Healer revive tokens, Guard (raid stub). (PR 2: all 16 combos' Novice and Adept services work in runs except the Guard's, which are collected as `raid.*` modifiers for M6. The Forge counts as level 2 until buildings. The Shrine's Grow stronger took over attribute points and shard leveling, with respec.)
- [x] Save/load of `ProfileState` with round-trip tests. (PR 1: the village joins the profile; old saves get the starting villagers.)
- [x] Forced first gift tutorial (GDD Section 16). (PR 3: the first power must go to the Farmer; the Elder's words are text only. The title's New game replays it. The tutorial floor and the Elder character wait for M7 onboarding.)
- [ ] Owner plays the loop (a New game through the first gift, then a free Choice) and checks the done criteria below.

**Done when:** the full loop Village > Run > Results > Choice > Village works and persists across restarts.

---

## M5: Training and Techniques (PROTOTYPE GATE)
Split into small PRs, each playable: (1) the training tick, rank-ups shown in the village, Renown levels 1 to 3 with the Healer arriving at Renown 2, (2) the 16 prototype Techniques, the lesson ceremony and the character sheet, (3) metrics logging, debug console commands and playtester builds.

- [x] `TrainingSystem.tick` with thresholds 3 and 7 (unit tested). (PR 1: every run leaves a tick in `ProfileState.training_due`; the village applies it once nothing waits at the Shrine, so a power given after a run trains with that run. The gate stays shut while a power waits. The results screen previews the tick.)
- [x] Rank-up presentation in the village (Adept visual, Master visual). (PR 1: a short moment per rank-up: bars, the camera on the villager, a burst, then their line and new service. Adept: a star in the power's color and a pennant on the roof. Master: a gold crown and a second, gold pennant. Names show Training Points, "Novice 2/3".)
- [x] 16 prototype Techniques implemented (modifier-based where possible, behavior scripts for Ember Step, Cold Temper and others). (PR 2: `TechniqueData` per combo, 13 are modifiers the hero reads, 3 are `TechniqueBehavior` scripts: Ember Step, Cold Temper, Cold Blood. Guard Techniques work in runs.)
- [x] Technique lesson ceremony; character sheet shows Techniques. (PR 2: the new Master calls the hero over right after their rank-up moment and teaches it: their line and what it does. The character sheet opens with the Map button in the village: level, attributes, max HP in runs, weapon, kept powers, Techniques and who taught them. The Codex entry waits for the Codex.)
- [x] Renown points and levels 1 to 3 (Healer arrival at Renown 2). (PR 1: points come from the village itself, +1 per villager holding a power and +2 per Master, so they cannot drift. A new level plays a moment with the newcomer fading in. Renown shows in the village's top right and on the notice board. The Healer no longer lives there from the start.)
- [x] Local metrics logging (GDD Section 17). (PR 3: `Metrics` autoload, opt-in with Playtest log on the title; one JSON file per session with every Choice and its time, run, rank-up, Technique and Renown level; `tools/metrics_report.gd` prints the gate numbers.)
- [x] Debug console commands (ARCHITECTURE Section 11). (PR 3: ` or F2 in debug builds: give_power, set_tp, add_renown, skip_room, god_mode, help.)
- [x] Build for playtesters (Windows and Linux). (PR 3: `export_presets.cfg` and the Playtest builds workflow, which exports, boots the Linux build and zips both with `docs/PLAYTEST.md`; release builds hide the test rooms and debug tools.)

**Prototype gate (must pass before M6):**
- [ ] 5+ external playtesters, 2+ hours each.
- [ ] 40% to 60% of powers given (metrics).
- [ ] Median Choice time 10 to 40 s.
- [ ] Most testers report hesitating on at least one Choice and being happy about a Master Technique.
- [ ] Testers ask to keep playing.

If the gate fails: iterate on numbers (TP thresholds, slot count, service strength) and ceremony presentation before adding anything new. Log findings in `MEMORY.md`.

**Playtest questions:** GDD Section 17.

---

## M6: Raids, Neighbors, Fusions
- [ ] `RaidDirector` + raid scene: gates, waves, building HP, towers, walls.
- [ ] Powered villagers cast raid spells scaled by rank.
- [ ] Damaged buildings and repair flow.
- [ ] Raid warning on the notice board; Watchtower.
- [ ] `NeighborSystem` + village map UI with glowing active paths (unit tested).
- [ ] Resonance.
- [ ] `FusionSystem` + Fusion meter + 6 prototype Fusions (pairs among Fire, Frost, Growth, Stone) (unit tested).
- [ ] Buildings: Training Grounds, Walls, Storehouse (with costs from GDD 15.1).

**Done when:** a player can see gifts defend the village in a raid, arrange villagers for neighbor bonuses, and fire a Fusion.

---

## M7: Vertical slice
- [ ] Final art direction for Mossy Hollow, village, hero, 4 villagers (all visual rank states for the 4 prototype powers).
- [ ] Music: village theme with layers, Mossy Hollow theme, boss theme, ceremony motif.
- [ ] SFX pass for combat and UI.
- [ ] Full Mossy Hollow content: 5 enemies, 2 elites, mini-boss, Warden of Roots both phases.
- [ ] Sword and Hammer weapons with mastery unlocks.
- [ ] Onboarding first hour (GDD Section 16) polished.
- [ ] Settings menu with accessibility options (GDD Section 18). (Controls remapping landed early at the owner's request: Controls on the title.)
- [ ] Steam page assets: capsule art, trailer capture from the slice.

**Done when:** 2 hours of polished play that could be shown publicly (demo quality).

---

## M8: Content expansion
- [ ] Powers: Storm, Wind, Light, Shadow (+ statuses Shock, Knockback, Radiant, Marked).
- [ ] Villagers: Miller, Baker, Hunter, Scholar.
- [ ] All 64 combos and 64 Techniques; content integrity test green.
- [ ] All 28 Fusions and Neighbor bonuses.
- [ ] Regions: Ember Mines, Frostpeak, Gloam Marsh (enemies, elites, mini-bosses, Wardens).
- [ ] Weapons: Spear, Bow; mastery 1 to 10 for all 4.
- [ ] Trinkets (40), events (20+).
- [ ] Buildings: Town Hall, Tavern (level 1), all workplace levels.
- [ ] Renown 1 to 10.
- [ ] Optional: `tools/csv_import.gd` for combos.
- [ ] Balance pass using metrics.

**Done when:** the full game minus final boss and story is playable for 20+ hours.

---

## M9: Story, endgame, Codex
- [ ] Narrative beats (GDD 10.4), memory fragments at the Shrine, villager dialogue sets.
- [ ] The Hoard region and the Hoarder (3 phases, phase 3 with villagers).
- [ ] Both endings.
- [ ] Apprentices (Renown 8).
- [ ] Seasons 1 to 10.
- [ ] Codex complete (all tabs, hints, rewards).
- [ ] Early Access readiness review.

**Done when:** a player can finish the game, see credits, and start Season 1.

---

## M10: Local co-op
- [ ] `InputSource` per device; second hero joins from the village.
- [ ] Camera that frames both players; leash distance.
- [ ] Enemy HP scaling, instanced loot.
- [ ] Shared Fusion.
- [ ] Save rules for a guest profile.
- [ ] Decide online transport (ENet vs Steam) and record in `MEMORY.md`.

**Done when:** two players can play a full run on one machine.

---

## M11: Online features
- [ ] Host-authoritative online co-op runs (MultiplayerSpawner/Synchronizer), lobby via Tavern.
- [ ] Village snapshot export/import; visiting a friend's village; guest Technique lessons.
- [ ] Raid help (lend a villager, async).
- [ ] Network testing with latency simulation.

**Done when:** two players on different machines can complete a run together, and villages can be visited.

---

## M12: Polish and release
- [ ] Performance pass on Steam Deck (60 FPS in raids).
- [ ] Controller glyphs, Steam Input, achievements (tied to Codex).
- [ ] Localization (start with 4 to 6 languages).
- [ ] Bug bash, crash reporting, save migration tests.
- [ ] Daily Run with leaderboard (post-launch if needed).
- [ ] Early Access launch, then 1.0.

---

## Always-on tasks
- Keep `MEMORY.md` status and decisions current.
- Keep `docs/GDD.md` balance tables in sync with `data/balance/balance_default.tres`.
- Every new rule gets a unit test; every new content type gets an integrity check.
- Playtest at the end of every milestone from M4 on.
