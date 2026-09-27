# Pass It On: Game Design Document

Version 0.1 (pre-production), 2026-09-27. Working title.

Content tables (every power, villager, combo, fusion, weapon, enemy) live in `docs/CONTENT.md`. This document defines the rules and numbers.

---

## 1. Overview

### 1.1 Pitch
**Every power you earn, you can keep, or give to a villager forever.**

You are the only hero of Emberwick, a small village at the edge of a drained land. Each dungeon run ends with a new power. Keep it and you are stronger now. Give it to a villager and their craft transforms: the smith forges fire swords, the farmer's crops ripen overnight. Villagers train the power, and when they master it they teach you a Technique you could never learn alone. The hero and the village grow together, and every gift is a bet on the future.

### 1.2 Design pillars
1. **The Choice is the heart.** Keep or give must be hard and interesting every time.
2. **Both sides grow.** Player and village each progress; giving is an investment.
3. **Depth from interaction, not rule count.** Every system fits in one sentence.
4. **See your choices.** Every gift visibly changes the village.
5. **Short runs, long arc.** 12 to 15 minute runs, 25+ hour game.

### 1.3 Every system in one sentence
| System | One sentence |
|---|---|
| The Choice | After each run, keep the new power (3 slots max) or give it to a villager forever. |
| Training | Villagers rank up a gifted power from Novice to Adept to Master over the next runs. |
| Techniques | A Master villager teaches you a permanent Technique. |
| Level | XP raises your level; each level gives health and one attribute point. |
| Weapon Mastery | Using a weapon unlocks its moves. |
| Power Levels | Power Shards level up the powers you keep, from 1 to 5. |
| Fusion | Your two highest-level kept powers (level 3+) combine into a Fusion ultimate. |
| Neighbors | Two powered villagers living next door create a village-wide bonus. |
| Buildings | Materials upgrade villager workplaces and village buildings. |
| Renown | Gifts, masteries and raid wins raise Renown, which brings new villagers. |
| Raids | Every few runs monsters attack the village, and your gifts defend it. |
| Seasons | After the credits, stacking difficulty tiers each add one twist. |

### 1.4 Audience and comparables
- Players of action roguelites with hub progression: Hades, Moonlighter, Dead Cells, Cult of the Lamb.
- Players of cozy village games who want more bite: Stardew Valley, Dragon Quest Builders.
- Comparable structure: Moonlighter (dungeon feeds town), Kingdom Two Crowns (power through others), Hades (boon synergies), Slay the Spire (branching map, Ascension).

### 1.5 Platform and scope
- PC (Steam) first, Steam Deck verified as a target. Gamepad first, keyboard and mouse fully supported.
- 2D top-down, pixel art, 640x360 base resolution.
- Single player at launch of Early Access; local co-op then online co-op later (Section 12).

---

## 2. Core loop

```
        +-------------------------------------------+
        |                                           |
        v                                           |
   [ VILLAGE ]  prepare: eat meal, buy gear,        |
        |       pick region, check raid warning     |
        v                                           |
   [ RUN ]  3 floors, branching rooms, boss         |
        |   earn XP, coins, materials, shards       |
        v                                           |
   [ RESULTS ]  XP, mastery, loot tallied           |
        |                                           |
        v                                           |
   [ THE CHOICE ]  new power: keep or give  --------+
        |
        v
   [ TRAINING TICK ]  every villager with a power gains Training Points,
                      rank-ups and Technique lessons play out
        |
        v
   [ RAID? ]  every 4th run: defend the village
```

- A **run** is one region: 3 floors, 12 to 15 minutes.
- A **failed run** still gives XP, weapon mastery, 50% of materials and coins, and still ticks training. It gives **no power**.
- A **successful run** gives one power (chosen from 2 offered by the region boss).

---

## 3. The Choice

### 3.1 Flow
1. Region boss dies. Two power orbs appear, drawn from the region's power pool. Player picks one. (The other is lost.)
2. Back in the village, the **Shrine** glows. Walking to it opens the Choice screen.
3. Options:
   - **Keep:** add to an empty slot. If all 3 slots are full, pick a kept power to give away instead (it goes to the gift flow) or discard the new power.
   - **Give:** choose any villager who does not already hold a power. The villager portraits show a preview of the Novice service, the Adept upgrade and the Master Technique **if already discovered in the Codex**; otherwise the Technique shows as "???".
   - **Merge:** if you already keep the same power, merging raises it +1 level (max 5).
4. **Gift ceremony** (5 to 8 seconds, skippable after first time): the power flows from hero to villager, the villager's sprite, workplace and shop change on screen, and the villager says a unique line.

### 3.2 Rules
- **Kept slots: 3.** Fixed for the whole game (Season 6 reduces it to 2).
- **Gifts are permanent.** A villager's power can never be taken back or swapped.
- **One power per villager.** Apprentices (Renown 8) add a second holder per job (Section 5.6).
- **The same power can be given to several villagers** (Fire to the Smith and Fire to the Baker is allowed).
- **Level carries over.** Giving a power at level L gives the villager `L - 1` starting Training Points (see 5.2). Leveling a power before giving it is a valid strategy.
- **You may also give a kept power at any time** at the Shrine, not only right after a run. This lets players react to raids and new villagers.

### 3.3 Why the Choice stays hard (design intent)
| Pressure toward keeping | Pressure toward giving |
|---|---|
| Immediate combat power for the next run | Only 3 slots, so the 4th power forces a decision |
| Fusions need two kept powers at level 3+ | Services help every future run |
| Leveled powers represent invested shards | Techniques are permanent and free up slots |
| Next region may need a specific element | Neighbor bonuses need powered villagers |
| | Raids scale; an unpowered village loses buildings |
| | Renown (+1 per gift, +2 per Master) unlocks villagers and story |

Target: across playtests, **40% to 60% of earned powers are given away**, and median decision time is **10 to 40 seconds**.

---

## 4. Player progression

### 4.1 Level and attributes
- Level cap **30**. XP needed to go from level n-1 to level n: `round(50 * n^1.5)` (level 2 = 141, level 10 = 1581, level 30 = 8216). Cumulative to level 25 is about 62,000 XP, roughly 100 runs, which matches the 25-hour arc.
- XP sources: combat room cleared 15, elite 60, mini-boss 100, region boss 200, raid won 150. Failed runs keep all XP earned.
- Each level: **+4 max HP** and **1 attribute point**.

| Attribute | Per point | Cap |
|---|---|---|
| Might | +3% weapon damage | 20 |
| Vigor | +10 max HP, +5 max stamina | 20 |
| Focus | +3% power damage, -1.5% power cooldowns | 20 |

- Respec at the Shrine for coins (cost `50 * level`).
- Base stats: 100 HP, 100 stamina, move speed 110 px/s.

### 4.2 Weapons and mastery
- 4 weapon types: **Sword, Spear, Bow, Hammer** (details in CONTENT.md). You carry one weapon per run, chosen in the village.
- **Mastery** 1 to 10 per weapon type. Mastery XP = 1 per 10 damage dealt with that weapon. Mastery n requires `150 * n^1.4` total XP.
- Unlocks by mastery: 2 dash attack, 4 charged attack, 6 special move, 8 finisher (on staggered enemies), 10 signature move.
- **Weapon tiers** (bought from the Smith): Iron x1.0, Steel x1.3, Runed x1.7, Mythic x2.2 base damage. Steel needs Forge level 2, Runed Forge level 3, Mythic Forge level 3 plus a Master Smith.
- **Infusions:** a Smith holding a power sells an infusion of that element (see CONTENT.md Smith combos).

### 4.3 Kept powers
- Each kept power is an active ability on its own button (Power 1, 2, 3).
- **Power level 1 to 5.** Raised with **Power Shards**: level 2 costs 3, level 3 costs 5, level 4 costs 8, level 5 costs 12 (28 total).
- Each level: +20% power damage. Level 3 and level 5 add an upgrade effect (CONTENT.md).
- Shards come from elites (1 to 2), mini-bosses (2), region bosses (3), treasure rooms (sometimes), and some village services.
- Levels persist between runs while the power is kept.
- Base cooldowns 4 to 8 seconds (per power). No mana.

### 4.4 Fusion
- Your **two highest-level kept powers** form your Fusion, if **both are level 3 or higher** and they are **different** powers. Ties: the most recently leveled power wins.
- The Fusion is an ultimate ability on its own button, charged by a **Fusion meter** (fills by dealing damage: 1 point per 8 damage, 100 to fill; taking damage does not drain it).
- 28 Fusions exist (one per power pair, CONTENT.md). Discovered Fusions go into the Codex.

### 4.5 Techniques
- Taught by a villager when they reach **Master** rank with a power. One unique Technique per villager+power pair (64 total).
- Techniques are **permanent passives**, always active, never take a slot.
- The Technique ceremony plays in the village after the training tick: the villager calls you over and teaches you (short animation, Codex entry).
- Techniques are how giving pays the player back. By the late game a player has 6 to 10 Techniques.

### 4.6 Player power budget (target)
| Hours | Level | Kept powers | Techniques | Weapon tier |
|---|---|---|---|---|
| 1 | 3 | 1 to 2 (lv 1 to 2) | 0 | Iron |
| 5 | 9 | 3 (lv 2 to 3), first Fusion | 1 | Steel |
| 12 | 17 | 3 (lv 3 to 4) | 3 to 4 | Runed |
| 25 | 25 | 3 (lv 4 to 5) | 6 to 8 | Mythic |
| Seasons | 30 | 3 (lv 5) | 8 to 12 | Mythic |

---

## 5. Village progression

### 5.1 Villagers
- 8 jobs: **Smith, Farmer, Guard, Healer, Miller, Baker, Hunter, Scholar** (CONTENT.md).
- Start with Smith, Farmer, Guard. Others arrive through Renown (5.5).
- Each villager has a **base service** without any power (so an unpowered village still works) and a workplace building.
- A gifted power changes the service according to the villager+power combo.

### 5.2 Training
- **Training Points (TP):** every villager holding a power gains **1 TP per run attempted** (win or lose), at the training tick after the Choice.
- Ranks: **Novice** at 0 TP, **Adept** at 3 TP, **Master** at 7 TP.
- Starting TP on gift: `power level - 1` (level 5 gift = 4 TP = already Adept, Master in 3 runs).
- Speed-ups: Training Grounds building (-1 TP needed per level for both thresholds, max 2 levels), some Scholar combos, some Neighbor bonuses.
- Typical pace: a level 1 gift reaches Master after 7 runs (about 1.75 hours). Tuned in M5 playtests.

### 5.3 Buildings
- Each villager workplace has **3 levels**. Level 2 and 3 increase that villager's service strength by +25% each and unlock extra shop items.
- Shared buildings:

| Building | Levels | Effect per level |
|---|---|---|
| Shrine | 1 | The Choice, respec, Codex, gift ceremonies |
| Town Hall | 3 | Renown display, raid planning; +1 house plot per level |
| Training Grounds | 2 | -1 TP to reach Adept and Master |
| Watchtower | 3 | Raid warning one run earlier; tower damage in raids +30% |
| Walls | 3 | Building HP in raids +40% |
| Storehouse | 3 | Material cap +100 each; keep +10% materials on death per level |
| Tavern | 2 | Level 1 rumors (next raid faction, boss hints); level 2 co-op visitors and village visits |

- Costs use three materials: **Wood** (Mossy Hollow, Gloam Marsh), **Ore** (Ember Mines, Frostpeak), **Crystal** (elites and bosses everywhere). Cost table in Section 15.

### 5.4 Layout and Neighbors
- The village has **house plots** connected by paths (starts with 6 plots, up to 12). Each plot is adjacent to 2 or 3 others (fixed map).
- Villagers live on plots. Moving a villager costs 50 coins and can be done once per visit.
- **Neighbor bonus:** two adjacent villagers who are both **Adept or higher** and hold **different** powers activate the village effect of that power pair's Fusion (same table as player Fusions, CONTENT.md).
- **Resonance:** two adjacent villagers holding the **same** power, both Adept+, give both of their services +25%.
- A villager can be part of several neighbor bonuses (one per adjacent pair).
- The village map UI shows active bonuses as glowing paths.

### 5.5 Renown
- Renown points: +1 per gift, +2 per villager reaching Master, +2 per raid won, +1 per building level.
- Renown levels (1 to 10) and unlocks:

| Renown | Points needed | Unlock |
|---|---|---|
| 1 | 0 | Smith, Farmer, Guard. Mossy Hollow. |
| 2 | 4 | Healer arrives. Raids begin (after run 4). |
| 3 | 9 | Miller arrives. Training Grounds. |
| 4 | 15 | Baker arrives. Town Hall level 2. |
| 5 | 22 | Hunter arrives. Tavern. |
| 6 | 30 | Scholar arrives. Town Hall level 3. |
| 7 | 39 | Festival event, cosmetic unlocks. |
| 8 | 49 | Apprentices. The Hoard can be entered (also needs all 4 Wardens defeated). |
| 9 | 60 | Mythic weapons for all types. |
| 10 | 72 | Village fully grown; final story beat before the Hoard. |

### 5.6 Apprentices (late game depth)
- From Renown 8, each **Master** villager can take one **Apprentice** of the same job, who lives on a new plot and can receive a **different** power.
- Apprentices use the same combo table (an Apprentice Smith with Frost behaves as Smith+Frost), train normally and teach Techniques.
- This doubles the reachable gift targets to 16, so a single playthrough can hold at most 16 combos out of 64. Replays and Seasons fill the Codex.

---

## 6. Runs

### 6.1 Structure
- Pick a region at the village gate. Each region has 3 floors.
- Each floor is a **branching node map** (like Slay the Spire): 5 to 7 rooms deep, 2 to 3 choices per step. The next room's type is shown on its door.
- Floors 1 and 2 end in a **mini-boss**. Floor 3 ends in the **region boss**.
- Between floors: a short safe corridor with the floor's merchant chance and a full view of the next map. The run also starts in the first floor's corridor.
- Doors to the next rooms sit in the top wall, left to right in the same order as the map. The Map button (Back / Tab) shows the whole floor.
- Map rules (tested in `test_run_generator.gd`): paths never cross; every room is reachable; the first row is always a fight; no Elites before the third row; a row never offers the same non-fight room twice. Room type chances per region are in Section 15.6.

### 6.2 Room types
| Room | Frequency | Content |
|---|---|---|
| Combat | 50% | 2 to 3 waves of enemies |
| Elite | 12% | One elite plus adds; 1 to 2 Power Shards, Crystal |
| Treasure | 10% | Coins, materials, sometimes a shard |
| Rest | 8% | Heal 30% or refill 1 flask |
| Merchant | 7% | Buy flasks, run-only trinkets, shards |
| Event | 8% | Short choice (risk for reward) |
| Village Echo | 5% | A powered villager appears and helps (Smith repairs = +10% dmg this floor, Healer heals, and so on). Only if you have a powered villager of that job. |

### 6.3 Run-only items
- **Trinkets** (bought or found): small run-only passives (+10% crit, heal on elite kill, and so on). Max 5 per run. Lost at run end. 40 trinkets in the full game (added in M8).
- **Flasks:** base 3 charges, heal 35% max HP. Farmer and Baker affect them.

### 6.4 Death
- Death ends the run. Keep XP, mastery, 50% of coins and materials (Storehouse increases this).
- No power awarded. Training still ticks.
- Healer services give **revive tokens** (revive at 30% HP, more with upgrades).

---

## 7. Combat

### 7.1 Controls (default gamepad / keyboard)
| Action | Gamepad | Keyboard and mouse |
|---|---|---|
| Move | Left stick | WASD |
| Aim | Right stick (or move direction) | Mouse |
| Attack | X / Square | Left click |
| Dodge | A / Cross | Space |
| Power 1 / 2 / 3 | LB / RB / Y | Q / E / R |
| Fusion | RT | F |
| Flask | D-pad up | 1 |
| Interact | B / Circle | Shift |
| Map (in runs) | Back / View | Tab |

### 7.2 Core numbers
- Dodge: 0.3 s roll, 0.22 s invincibility, 25 stamina. Stamina regen 40 per second after 0.5 s delay.
- **Perfect dodge:** dodging within 0.12 s of a hit gives a brief slow-motion (0.3 s) and +10 Fusion meter.
- Crit: base 5% chance, x1.5 damage.
- Damage formula: `final = base * weapon_tier * (1 + might_bonus + other_bonuses) * crit * status_mods * (1 - armor)`. Armor capped at 60%.
- Enemies flash and have a 0.15 s hit-stop on heavy hits for game feel.

### 7.3 Status effects
| Status | Source | Effect |
|---|---|---|
| Burn | Fire | 3 damage per second for 4 s, stacks to 3 |
| Chill | Frost | -30% move and attack speed; 3 stacks = Freeze 1.5 s |
| Shock | Storm | Next hit on the target chains to 2 nearby enemies for 50% |
| Stagger | Stone, Hammer | Fills a stagger bar; full bar = stunned 1.5 s. Bosses have larger bars. |
| Root | Growth | Cannot move for 2 s (can still attack) |
| Knockback | Wind | Pushed away; hitting a wall stuns 0.8 s |
| Radiant | Light | Takes +20% damage for 5 s, visible through darkness |
| Marked | Shadow | Next hit is a guaranteed crit |

- Bosses: status durations halved, cannot be Frozen or Rooted (Chill and Root fill their stagger bar instead).

### 7.4 Enemy archetypes
Chaser, Charger, Ranged kiter, Ambusher, Tank, Summoner, Swarm, Bomber. Each region reskins and remixes these with one unique twist per enemy (CONTENT.md). Enemies telegraph every attack (0.4 to 0.8 s wind-up with a visual cue).

---

## 8. Raids

- **When:** after every 4th run, starting after run 4 (so runs 4, 8, 12 ...). The Watchtower warns one run ahead (two with upgrades), showing the raiding faction.
- **What:** a 3 to 5 minute wave defense in the village. Enemies come from 1 to 3 gates and target buildings.
- **Defenders:**
  - You (with your kept powers and weapon).
  - The **Guard** and their towers and walls.
  - **Every powered villager** casts their power's basic spell periodically, strength scaled by rank (Novice 1x, Adept 1.5x, Master 2x). This is where gifts are most visible.
  - Some combos add specific raid effects (Guard combos especially).
- **Win:** survive all waves with the Town Hall standing. Rewards: +2 Renown, 150 XP, materials, sometimes a free Power Shard bundle.
- **Lose:** 1 to 2 buildings become **damaged** (their service is disabled until repaired with materials). **Villagers never die and powers are never lost.**
- **Scaling:** raid strength follows run count and highest region cleared, so a village with no gifts will start losing raids around run 12.

---

## 9. Economy

| Currency | Sources | Sinks |
|---|---|---|
| Coins | Enemies, treasure, Miller income | Weapons, infusions, meals, respec, moving villagers, merchant |
| Wood, Ore | Region-specific drops, Farmer and Miller services | Building upgrades |
| Crystal | Elites, bosses, raids | High-level buildings, Mythic weapons |
| Power Shards | Elites, bosses, some services | Power levels |
| XP | Everything | Levels |
| Renown | Gifts, Masters, raids, buildings | (Not spent; unlock track) |

- Material cap: 100 each (Storehouse raises it). Coins uncapped.
- Target: a player can afford roughly one meaningful village upgrade per 2 runs.

---

## 10. Story and world

### 10.1 Setting
- **The Vale.** Long ago, magic lived in **Sparks** shared by everyone: every baker, farmer and guard had a little.
- A great hero, **Aurel**, gathered the Sparks to fight a catastrophe and won. Then Aurel could not let go. Hoarding every Spark, Aurel became **the Hoarder**, sealed inside **the Hoard**, while the Vale grew grey and ordinary.
- Sparks still leak from the Hoard into the wild places, where the Hoarder's four **Wardens** guard them.
- **Emberwick** is the last village that remembers the old way. You are its only hero.

### 10.2 Theme
Power shared is power multiplied. The game rewards letting go, and the villain is what happens when you do not.

### 10.3 Regions
| Order | Region | Power pool | Warden |
|---|---|---|---|
| 1 | Mossy Hollow | Growth, Wind, Stone | Warden of Roots |
| 2 | Ember Mines | Fire, Stone, Storm | Forge Warden |
| 3 | Frostpeak | Frost, Wind, Light | Pale Warden |
| 4 | Gloam Marsh | Shadow, Growth, Storm | Hollow Warden |
| Final | The Hoard | All | The Hoarder |

- Unlocks: Mossy Hollow at start; Ember Mines after the Warden of Roots; Frostpeak and Gloam Marsh after the Forge Warden; the Hoard after all 4 Wardens and Renown 8.
- Note: Fire only appears in Ember Mines, Frost and Light only in Frostpeak, Shadow only in Gloam Marsh. Region choice is a strategic decision.

### 10.4 Narrative beats
| Trigger | Beat |
|---|---|
| First run | Tutorial. Elder explains Sparks. First power: the Choice is forced to be a gift (to teach it), later Choices are free. |
| First Master | Villager teaches first Technique. Elder hints that Aurel had no one to teach. |
| Each Warden defeated | Memory fragment of Aurel's story plays at the Shrine. |
| Renown 5 | Tavern opens; a traveler tells of other villages that fell. |
| Renown 10 | Festival. Villagers vow to march with you. |
| The Hoard | Final run: 3 floors of mixed enemies, then the Hoarder fight in 3 phases. **Phase 3 is fought alongside your powered villagers**, who use their Master abilities. |

### 10.5 Ending
- After the Hoarder falls, the Hoard of Sparks opens. Final choice:
  - **Release it:** Sparks return to the whole Vale. Credits over a montage of your village and others waking up. (Good ending.)
  - **Take it:** You become the next Hoarder. Screen fades to grey. A new hero appears in a new village. (Secret ending, starts Season 1 with a twist: the final boss uses your build.)
- After credits: Seasons unlock; the village and player persist.

---

## 11. Endgame

### 11.1 Seasons (stacking difficulty, like Slay the Spire's Ascension)
| Season | Added twist |
|---|---|
| 1 | Elites appear 50% more often |
| 2 | Villagers need +1 TP for each rank |
| 3 | Raids are 30% stronger |
| 4 | Flasks heal 25% instead of 35% |
| 5 | Region bosses gain an extra attack pattern |
| 6 | Only 2 kept power slots |
| 7 | Enemies deal +25% damage |
| 8 | Neighbor bonuses need both villagers at Master |
| 9 | No Rest rooms |
| 10 | Hoarder's Greed: each kept power costs 5% max HP |

- Starting a Season resets the village and player to a fresh start **except** Codex discoveries and cosmetics. (Decided: Seasons are new playthroughs, so the Choice matters again. Revisit if playtests say otherwise.)
- Each Season win unlocks a cosmetic and a village decoration.

### 11.2 Codex
- Tracks: 64 combos, 64 Techniques, 28 Fusions, 28 Neighbor bonuses, Resonance for each of 8 powers, bestiary (all enemies), trinkets, lore.
- Discovering an entry reveals its full text; undiscovered entries show "???" (Scholar combos can reveal hints).
- Completion rewards: cosmetics, village decorations, a title screen change.

### 11.3 Daily Run (post-launch)
- Fixed seed, fixed starting build, online leaderboard. Does not affect the save.

---

## 12. Multiplayer (optional, later)

### 12.1 Modes
| Mode | Type | Milestone |
|---|---|---|
| Co-op runs (2 players) | Local first, then online | M10 local, M11 online |
| Village visits | Online, async snapshot | M11 |
| Raid help | Online, async | M11 |

### 12.2 Co-op runs
- The host's region and village buffs apply. The guest brings their own hero (level, weapon, kept powers, Techniques).
- Enemy HP scales +70% per extra player. Loot is instanced per player.
- **Shared Fusion:** if the two players' strongest powers form a Fusion pair, a joint Fusion can be triggered when both meters are full (double effect).
- The guest earns XP, mastery, materials and coins for their own save. Only the host gets the boss power; the guest gets a Power Shard bundle instead.

### 12.3 Village visits
- Via the Tavern (level 2): enter a friend's village snapshot. Shop from their powered villagers (buy their infusions, meals), see their layout.
- **Technique lessons:** a friend's Master villager can teach you their Technique **for one run only** ("guest lesson"). Encourages visiting friends with different villages.

### 12.4 Raid help
- Lend one of your powered villagers to a friend's next raid (async). The lent villager fights in their raid as an AI defender. Both players get +1 Renown if the raid is won.

### 12.5 Constraints for single player code now
See `docs/ARCHITECTURE.md` Section 9. Summary: no per-player state in autoloads, input decoupled from character, all run state serializable.

---

## 13. UI and screens

| Screen | Contents |
|---|---|
| Title | Continue, New Game, Seasons, Settings, Codex, Quit |
| Village (diegetic) | Walk around; interact with villagers (shop, info), Shrine, gate, notice board (raid warning) |
| Village map | Plots, villagers, powers, ranks, TP progress bars, active neighbor bonuses |
| Choice screen | New power card (stats, level), 3 kept slots, villager portraits with preview, Keep / Give / Merge |
| Gift ceremony | Full-screen moment, skippable |
| Character sheet | Level, attributes, weapon mastery, kept powers and levels, Fusion, Techniques |
| Run map | Branching node map for the current floor |
| Run HUD | HP, stamina, flask charges, power cooldowns, Fusion meter, coins, shard count, trinkets |
| Results | XP gained, mastery gained, loot, training tick preview |
| Codex | Tabs: Combos, Techniques, Fusions, Neighbors, Bestiary, Lore |
| Settings | Controls rebinding, audio, video, accessibility |

- UI style: hand-lettered, warm parchment in the village; darker, sharper frames in dungeons.

---

## 14. Art and audio direction

- **Village:** warm, cozy palette (ochre, moss green, soft reds). Every power has a clear visual identity on villagers and buildings (Fire: glowing forge, embers; Frost: icicles, blue light; Growth: vines and flowers; and so on).
- **Dungeons:** saturated and dangerous; each region has its own palette and ambient particles.
- **Power colors** (consistent everywhere, also shown with an icon shape for colorblind players): Fire orange, Frost ice blue, Storm yellow, Stone brown, Growth green, Wind pale teal, Light gold, Shadow violet.
- **Sprites:** 32x32 characters, 4-direction movement, 8 frames walk, readable silhouettes. Villagers get 4 visual states (base, Novice, Adept, Master) per power family (color and prop swaps, not full redraws).
- **Audio:** village theme evolves as villagers gain powers (each powered villager adds an instrument layer). Region themes per biome. Gift ceremony has a signature motif.

---

## 15. Balance tables

### 15.1 Building costs
| Level | Wood | Ore | Crystal |
|---|---|---|---|
| Workplace 2 | 30 | 20 | 0 |
| Workplace 3 | 60 | 50 | 5 |
| Shared building 1 | 25 | 25 | 0 |
| Shared building 2 | 50 | 50 | 3 |
| Shared building 3 | 90 | 90 | 8 |

### 15.2 Weapon prices (coins)
| Tier | Price |
|---|---|
| Iron | free (starting) |
| Steel | 300 |
| Runed | 900 |
| Mythic | 2500 plus 10 Crystal |

### 15.3 Drops per run (averages for a full successful run)
| Resource | Amount |
|---|---|
| Coins | 250 to 400 |
| Region materials | 25 to 40 |
| Crystal | 2 to 4 |
| Power Shards | 4 to 6 |
| XP | 450 to 650 |

### 15.4 Pacing targets
| Metric | Target |
|---|---|
| Run length | 12 to 15 min |
| Village visit | 2 to 4 min |
| First gift | Minute 15 (tutorial) |
| First Master | Around hour 2 |
| First Fusion | Around hour 3 to 4 |
| First Warden beaten | Hour 1 to 2 |
| Credits | Hour 20 to 25 |
| Codex completion | 60+ hours |

### 15.5 Combat feel (M1)
Live values are in `data/balance/balance_default.tres` and `data/weapons/weapon_sword.tres`.

| Number | Value |
|---|---|
| Hero acceleration / friction | 1000 / 1400 px/s per second |
| Dodge distance | 72 px (about 2 tiles) over 0.3 s |
| Hurt stagger / grace i-frames after a hit | 0.2 s / 0.6 s |
| Input buffer (attack, dodge, flask) | 0.15 s |
| Combo continues if you attack again within | 0.35 s after a swing ends |
| Flask drink time / move speed while drinking | 0.4 s / 40% |
| Hit-stop | Sword finisher 0.07 s, crits +0.03 s, hero hit 0.05 s |

| Sword step | Damage | Wind-up | Active | Recovery | Knockback |
|---|---|---|---|---|---|
| 1 | 12 | 0.06 s | 0.08 s | 0.20 s | 90 |
| 2 | 12 | 0.06 s | 0.08 s | 0.20 s | 90 |
| 3 (finisher) | 20 | 0.12 s | 0.10 s | 0.32 s | 240 |

- The next combo step can start 0.06 s into recovery if attack was pressed during the swing. Dodge cancels recovery.
- A flask charge is used when the heal lands. Getting hit while drinking cancels the drink and keeps the charge.
- Enemies do not crit unless their data says so.
- The hero rolls through enemy bodies during a dodge (walls still block).
- **Stick aim assist:** with a gamepad, a new swing turns toward the target closest to the aim line within 30 degrees either side and 64 px. Mouse aim is never assisted. Set the angle to 0 to turn it off.
- **Rumble:** light tap on each sword hit (stronger on crits and the finisher), 0.6 for 0.18 s when the hero is hit. `rumble_strength` scales it (0 = off, also the future accessibility slider).
- **Low stamina:** pressing dodge without enough stamina blinks the stamina bar red.
- Tune these live in the Tuning room (title screen) with a controller: Start opens the tuning menu. F4 opens it in any room (docs/ARCHITECTURE.md Section 11).

| Enemy (Mossy Hollow) | HP | Speed | Attack | Damage | Wind-up | Notes |
|---|---|---|---|---|---|---|
| Sproutling | 20 | 65 | Bite | 6 | 0.45 s | Splits into 2 Seedlings on death |
| Seedling | 8 | 80 | Bite | 3 | 0.40 s | Does not split |
| Tusk Boar | 60 | 40 (charge 260) | Charge, 0.9 s | 14 | 0.70 s | Hits do not interrupt it; a wall stuns it 1.6 s |
| Thorn Archer | 30 | 55 | Arrow (190 px/s, 240 px range) | 8 | 0.60 s | Keeps ~130 px away; a missed arrow leaves thorns (4 dmg every 0.8 s, 4 s) |

- Waves: enemies appear 0.7 s after a spawn marker, away from the hero when possible. The next wave starts 1.2 s after a clear. The M1 test room is 3 Sproutlings; a Boar and 2 Sproutlings; 2 Archers, a Boar and a Sproutling.
- Live values: `data/enemies/*.tres` and `data/encounters/encounter_mossy_test.tres`.

### 15.6 Runs (M2)
Live values: `data/regions/region_mossy_hollow.tres` and `data/balance/balance_default.tres`.

| Number | Value |
|---|---|
| Floors per region | 3 |
| Rows per floor before the exit | 5 to 7 |
| Rooms per row | 2 to 3 |
| Chance of each extra door between rows | 60% |
| Room type weights (rows 2+) | Fight 50, Elite 12, Treasure 10, Event 8, Rest 8, Merchant 7 (Village Echo 5 arrives with powered villagers in M4+) |
| Rest room | Heal 30% max HP, or +1 flask charge |

- Mossy Hollow fight rooms draw from 4 encounters (2 to 3 waves). Elite, Mother Toad and Warden rooms use stand-in wave encounters until those enemies exist (M2 PR 3).

All numbers here are starting points for tuning. Update this section when they change.

---

## 16. First hour (onboarding script)

1. **Minute 0 to 3:** Wake up in Emberwick. Walk to the Elder. Learn movement, attack, dodge on training dummies.
2. **Minute 3 to 12:** First run in Mossy Hollow, short tutorial floor (4 rooms, then the Warden of Roots in a weakened intro form). Get Growth.
3. **Minute 12 to 15:** Choice tutorial. The Elder asks you to give this first Spark to the Farmer (forced gift). Gift ceremony. Crops sprout instantly (Novice service: extra flasks).
4. **Minute 15 to 30:** Second run (full Mossy Hollow). Earn a power; this Choice is free. Tooltip explains slots.
5. **Minute 30 to 45:** Third run. Training tick: Farmer reaches Adept (3 TP). Village visibly changes.
6. **Minute 45 to 60:** Fourth run, then first raid warning. Buildings introduced.

Goal: by the end of hour 1 the player has made at least 3 Choices, seen a rank-up, and understands that gifts come back.

---

## 17. Metrics and playtesting

Log locally (opt-in for testers) to a JSON file per session:
- Each Choice: power, level, keep/give/merge, target villager, time spent on screen.
- Run: region, duration, result, cause of death, room path.
- Rank-ups, Technique unlocks, Fusion used, neighbor bonuses active.
- Raids: result, buildings damaged.

Key questions for every playtest:
1. Did you hesitate on the Choice? Why?
2. Did you ever regret a gift? A keep?
3. When a villager reached Master, how did it feel?
4. Did you notice the village change?
5. What made you want one more run?

---

## 18. Accessibility

- Full control rebinding, hold/toggle options, aim assist for bow.
- Colorblind-safe power icons (shape plus color), status icons with symbols.
- Screen shake, flash and rumble intensity sliders; option to disable hit-stop; stick aim assist strength (0 turns it off).
- Game speed option (70% to 100%) and an **Assist mode** (damage taken reduction, extra flask) that does not lock content.
- Text size scaling, dyslexia-friendly font option, subtitles for all voiced barks.
