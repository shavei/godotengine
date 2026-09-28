# MEMORY.md

Persistent project memory. Read at the start of every session, update at the end.

## Current status

- **Phase:** M0 done. M1 (combat core) code done; only the owner's gamepad playtest item is still open. M2 (run structure): all 4 PRs merged (the owner's run-length and death-rule answers are still welcome). M3 (kept powers) started at the owner's request: PR 1 of 3 (powers, abilities at level 1, statuses, HUD slots, keep/merge rules) open for the owner to play in the Tuning room.
- **Also:** Controls remapping menu (title > Controls) added at the owner's request, ahead of the M7 Settings menu.
- **Next step:** Owner tries the four powers in the Tuning room (menu: turn powers on, spawn enemies or a boss) and answers the M3 PR 1 questions in the session log. Then M3 PR 2 (level 3/5 upgrades, shard costs, leveling on results, Focus) and PR 3 (boss orbs and the keep screen).
- **Also:** Combat feel pass (merged): quick turns, swings keep momentum, stable facing, no swallowed finisher press. Owner feedback on it still welcome.
- **Last updated:** 2026-09-28 (M3 PR 1)

## The game in brief

**Pass It On** (working title). 2D top-down action roguelite RPG plus village building, in Godot 4.

- Every run ends with a new power. Keep it (up to 3 slots) or give it to a villager forever.
- A given power is trained by the villager: Novice (instant service), Adept (better service), Master (teaches the player a permanent Technique).
- Player grows through Level, Weapon Mastery, Kept Powers (with Fusions) and Techniques.
- Village grows through Villager Ranks, Buildings, Neighbor Bonuses and Renown.
- Villain: The Hoarder, an ancient hero who kept every power and became a monster.
- Single player first; co-op runs, village visits and raid help come later.

## Local environment (owner's machine)

- Windows. Godot 4.7.2 standard build at `C:\Godot\Godot_v4.7.2-stable_win64.exe` (console build `Godot_v4.7.2-stable_win64_console.exe` in the same folder, use it for MCP and command-line runs).
- Repo clone: `C:\Users\yosef\Documents\GitHub\godotengine` (GitHub Desktop).
- **Workflow (chosen 2026-09-27):** Claude works in a cloud session (installs Godot 4.7.2 headless there, runs tests, boot check and screenshots via xvfb), pushes one small feature per PR into `main`. Owner pulls the branch in GitHub Desktop, plays it with F5 in local Godot, gives feel feedback, and merges.
- Opening the project in the local editor can make Godot rewrite files (it re-saved `project.godot` in full format once). Such changes should go on the PR branch, not straight to `main`, to avoid conflicts.
- Option kept for later: Claude Code locally with the Godot MCP server `@coding-solo/godot-mcp`.

## User preferences (from the owner, shavei)

- **Never use em dashes** anywhere (docs, UI text, commits, chat).
- Wants a genuinely original idea, **backed by real research** into existing games. Checks that claims of originality are verified.
- Wants it **addictive** and with **lots of depth**, but rejected an earlier idea as "too complicated, convoluted". Depth must come from simple rules interacting.
- **Both the player and the village must progress.** Giving must not only weaken the player.
- Single player with options for multiplayer.
- Likes RPG elements.

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-09-27 | Chose "Pass It On" concept over "Double or Nothing" and "Forget Me" | Simplest to explain, emotional hook (your village), natural multiplayer. Prior-art search found no game where the hero permanently gives powers to villagers to build the town. |
| 2026-09-27 | Giving is an investment: Novice, Adept, Master ranks, Master teaches a Technique | User wants both player and village to progress. Turns keep/give into a timing decision (strong now vs stronger later). |
| 2026-09-27 | Hard cap of 3 kept power slots | Loss aversion research: players hoard. The cap forces regular giving. |
| 2026-09-27 | One fusion table used twice (player Fusion ability, village Neighbor bonus) | Adds depth without adding a new rule set to learn. |
| 2026-09-27 | Raids never kill villagers or remove powers; failure only damages buildings | Losing a gift would punish the core fantasy and push players back to hoarding. |
| 2026-09-27 | Godot 4, GDScript, 2D top-down pixel art at 640x360 | Fits the scope of a small team, fast iteration, good 2D tooling. |
| 2026-09-27 | Content as Resources, rules as pure RefCounted classes | Add content without code; unit-test rules headless. |
| 2026-09-27 | Pinned Godot 4.7.2 (standard build) and GUT 9.7.1 | Owner installed 4.7.2; GUT 9.7.1 is the release built for 4.7. |
| 2026-09-27 | Compatibility (GL) renderer | 2D pixel art needs nothing from Forward+; Compatibility runs on the widest range of hardware, including older laptops. |
| 2026-09-27 | Stretch mode `canvas_items` + integer scale (briefly `viewport` in M0, reverted) | Owner found text blurry with `viewport` (text drawn at 640x360 then enlarged). `canvas_items` renders text and UI at screen resolution while pixel art still scales by whole numbers. Verified with before/after screenshots. |
| 2026-09-27 | Gamepad Fusion button is RT (was LT + RT) | Godot's InputMap cannot express a two-button chord; one trigger is simpler and frees LT. |
| 2026-09-27 | M1 split into 3 PRs: hero core, enemies and waves, feel and tuning | Matches the one-feature-per-PR workflow; the owner can judge movement and dodge feel before enemies are tuned around them. |
| 2026-09-27 | Hero scene in `scenes/actors/hero/` with one script per state in `states/`; hero drives its StateMachine explicitly | Keeps the hero's files together; explicit update order (input buffer, stamina, i-frames, then state) avoids frame-order bugs. |
| 2026-09-27 | Attacks are `AttackData` resources shared by weapons and enemies; tunables in `BalanceData` (`data/balance/balance_default.tres`) | Data-driven rule from CLAUDE.md; tuning feel needs no code changes. |
| 2026-09-27 | Flask charge is used when the heal lands; a hit while drinking cancels and keeps the charge | Kinder while enemies are untuned. Revisit in M1 PR 3 if drinking mid-fight feels risk-free. |
| 2026-09-27 | Hit-stop restores speed by request counter, not by clock comparison | Found in a render test: comparing millisecond clocks could leave the game stuck at 5% speed. Regression test added. |
| 2026-09-27 | Zero GDScript warnings policy, enforced in CI by `tools/check_warnings.gd` | Owner saw 15 warnings in the editor debugger that headless tests could not show. EventBus is exempt from unused-signal (by design other scripts emit its signals). |
| 2026-09-27 | One enemy scene; behavior is an `EnemyAI` script picked by `EnemyData.ai_script` (Swarm, Charger, Ranged) | A new enemy of an existing archetype is a `.tres` only, per the data-driven rule. AI is a small phase machine, simpler than node states for enemies. |
| 2026-09-27 | The hero rolls through enemy bodies during a dodge | Answers the M1 open question: swarms could otherwise pin the hero against walls, and the dodge should always be an escape. Walls still block. |
| 2026-09-27 | Waves count split children as part of the wave; enemies count as alive from their spawn marker | A wave can never clear while seedlings or pending spawns remain. Rules in `WaveTracker` with tests. |
| 2026-09-27 | Thorn Archer arrows leave a thorn patch only when they miss | A hit already punishes; the patch punishes dodging carelessly and shrinks the room while the archer lives. |
| 2026-09-27 | Wave room is a separate scene (title: "Wave room"); the dummy test room stays | Dummies are still useful for practicing combos and dodge timing without enemies around. |
| 2026-09-27 | Melee aim assist for sticks only (30 degrees, 64 px), never for the mouse | A melee swing aimed by the move stick misses targets a few degrees off, which reads as the game's fault. Mouse aim is already precise. Pure `AimAssist` rules with tests; angle 0 turns it off. |
| 2026-09-27 | Rumble goes through `InputSource.rumble()` | The source knows which gamepad (and later which player or peer) the hero belongs to, so rumble stays per player for co-op. |
| 2026-09-27 | F4 `TuningPanel` edits the live `BalanceData`, Enter saves the `.tres` | Claude cannot feel a gamepad; the owner tunes while playing and the saved file (or the printed lines) comes back in the PR. |
| 2026-09-27 | Tuning room plus a controller-driven tuning menu that pauses the game; Save writes only the changed lines of `balance_default.tres` | Owner asked to tune with the controller and get results to GitHub. `ResourceSaver` would drop every value equal to the script default (found in a test save), so the panel edits lines in place for a clean diff. The summary also goes to the clipboard and `user://tuning_results.txt`. |
| 2026-09-27 | Started M2 with the M1 gamepad playtest still open | Owner asked to start M2. All M1 code is merged; feel tuning can continue with F4 in any run room. |
| 2026-09-27 | M2 split into 4 PRs: maps and room flow, drops and room types, bosses, XP/results/death/save | Same one-feature-per-PR workflow as M1; the owner can judge map pacing before loot is tuned around it. |
| 2026-09-27 | One `room.tscn` for every run room, reloaded through SceneRouter per room; `RunState` in `GameState.run` carries the run between rooms | Simple, every room starts clean, and the fade doubles as the room transition. Hero HP and flasks carry over via `RunState.heroes[player_id]`. |
| 2026-09-27 | Doors sit in the room's top wall in map lane order, signed with a room type letter and name | GDD 6.1 "the next room's type is shown on its door". Same order as the map so the map and the room agree. Letters keep types readable without color. |
| 2026-09-27 | Map rules: first row always a fight, no Elites before row 3, no duplicate non-fight room in a row, paths never cross | Each is one sentence and tested. A run should open with a fight, not a shop; duplicates in a row would make the door choice empty. |
| 2026-09-27 | Map action on Back (gamepad) and Tab | Back was unused; Tab is the common map key. |
| 2026-09-27 | Elite, Mother Toad and Warden rooms use stand-in wave encounters in M2 PR 1 | A full run can be played end to end now; the real enemies replace the `.tres` references in PR 2 and PR 3 without code changes. |
| 2026-09-27 | Esc leaves the run straight to the title (no confirm) for now | A pause menu is not in the design docs yet; revisit when the results screen and mid-run save land (M2 PR 4). |
| 2026-09-27 | Controls remapping added now (owner request), ahead of the M7 Settings menu | Owner asked to remap keys and buttons in game. One keyboard and one gamepad input per action; taking a used input swaps; right stick stays aim. Saved in `user://settings.cfg` (per machine, not in the profile). Menu on the title only until a pause menu exists. |
| 2026-09-27 | Owner's F4 tuning adopted: acceleration 1100, aim assist 60 degrees / 84 px, rumble strength 5 | Owner played with a gamepad and saved these (commit b87b8c9). GDD 15.5 synced. Rumble 5 means most rumbles are at the device cap. |
| 2026-09-27 | On-screen hints read the live bindings (`InputBindings.hint`) | Hardcoded "Shift / B" text would lie after a remap. |
| 2026-09-27 | Hero moves while attacking at 60% speed (`attack_move_scale`, tunable in F4) | Owner: "can't attack and move at the same time". The swing direction still locks at the start, so aiming stays a commitment. 0 restores the old rooted swing. |
| 2026-09-27 | Physics interpolation on (project setting); room cameras run on physics ticks | Owner: movement "not very smooth". Actors move 60 times a second but screens draw at 120+ Hz, and the camera followed per frame, so the hero stuttered against the world. Transform tweens run on physics ticks; nodes placed after entering the tree call `reset_physics_interpolation()`. |
| 2026-09-27 | Hero `wall_min_slide_angle = 0` | Owner: hero "sometimes gets stuck". Godot's default (15 degrees) stops a floating body that pushes into a wall at a slant, easy to do with a stick. Found with a probe test, regression test added. |
| 2026-09-27 | Run loot goes into a per-hero `Wallet` in `RunState.wallets[player_id]`; the profile gets it at run end (M2 PR 4) | Death keeps only 50% (GDD 6.4), so run loot must stay separate until the run ends. Keyed by player so co-op heroes keep their own loot. |
| 2026-09-27 | Drops are `DropTable` resources inline in `EnemyData` and `RegionData`, rolled by pure `LootRoller` with a per-room seed | Data-driven, no drop tables by name in code. Seeded so co-op peers agree (ARCHITECTURE 9). Standalone drop table files would need an `id` for ContentDB, so they stay inline. |
| 2026-09-27 | Pickups pop out, drift to a hero within 40 px, fly to the hero after a room clear, and are scooped up when leaving | Loot should feel good to see, but chasing coins after a fight is busywork and losing loot to a door is a trap. |
| 2026-09-27 | Merchant (basic) sells a flask (30), a 25% heal (25) and a Power Shard (60), each once; trinkets wait for M8 | GDD 6.2 lists flasks, trinkets and shards; trinkets have no data yet. A shard for 60 coins makes coins vs power a small Choice of its own. Wares with no use (full flasks or HP) are greyed out. |
| 2026-09-27 | Events are `EventData` resources (choices with a cost, HP cost, chance, reward); the last choice is always free; HP costs never kill | Risk for reward (GDD 6.2) without surprise deaths. Two samples for Mossy Hollow: Mossy Shrine (blood for a shard) and Wishing Well (coins or HP for a gamble). |
| 2026-09-27 | Elites: Elder Boar (ChargerAI with `charge_chain` 3) and Spore Witch (new `SummonerAI`: spore clouds at your feet, calls Sproutlings, capped at 4 alive); one elite plus adds in one wave | From CONTENT 6.1. Chains reuse the charger; a wall stun ends the chain so baiting still pays. The summon cap stops a slow player from being buried. |
| 2026-09-27 | Synced docs and a test with the owner's latest `balance_default.tres` (dodge 60 px, regen delay 0.7 s, aim assist back to 30 degrees / 64 px, rumble back to 1) | The owner's edit on `main` made `test_default_balance_matches_gdd_core_numbers` fail and left GDD 15.5 out of date. |
| 2026-09-27 | Bosses use the one enemy scene with `BossData` (extends `EnemyData`) and a boss AI per boss; moves follow a fixed repeating order (`BossPattern`), with one enrage switch | A fixed order is learnable, the core of a fair boss. Same scene keeps hit, loot and wave code shared. A new boss needs its own AI script (unique moves) but its numbers and order are data. |
| 2026-09-27 | Mother Toad: tongue pulls you in, belly flop leaps to your spot (no hits mid-air), sits still 1.3 s after landing; enrages at 50% and flops twice in a row | CONTENT 6.1 "tongue grabs, belly-flop area attacks". The pull sets up the flop, and the long landing pause is the reward for dodging it. |
| 2026-09-27 | Warden of Roots phase 1 never walks: seed volleys, root walls on either side of you, a root slam if you stand next to it; walls block seeds too | CONTENT 6.1 "root walls and seed bullets". Walls make a lane the next volley comes down, but also shelter you from the outer seeds: one rule, two uses. The slam stops hugging it from being free. |
| 2026-09-27 | Boss drops follow GDD 4.3 per-source shards (mini-boss 2, region boss 3), even though a full run then gives 10 to 11 shards vs the 15.3 target of 4 to 6 | Shards have no use until M3, so there is nothing to tune against yet. Flagged in Open questions. |
| 2026-09-27 | Thorn Archer arrows no longer `monitorable = false` | Found while testing root walls: a non-monitorable Area2D never reports static bodies, so arrows flew through walls and pillars to full range. Regression test added. |
| 2026-09-28 | Profile save now exists: `ProfileState` (run count, heroes by player_id) and `HeroState` (level, XP, attribute points, attributes, weapon mastery, `bank` Wallet) saved to slot 0; the village joins in M4 | XP and banked loot mean nothing unless they last. The roadmap had ProfileState save/load in M4; only the hero part is pulled forward. The bank reuses `Wallet` so run loot and banked loot share one currency list. |
| 2026-09-28 | A run is banked the moment it ends (boss dies or hero falls), before the results screen; the run save is deleted then | Quitting during the "You fell" pause or on the results screen cannot undo a fall or lose a clear. |
| 2026-09-28 | The 50% death rule applies to every run currency (coins, Wood, Crystal, shards), rounded down | GDD 6.4 names coins and materials only; one rule for all is simpler to explain. Shards have no use yet, revisit in M3 if keeping half feels harsh. |
| 2026-09-28 | Run XP is added to the level at the run's end; cleared fights show "+N XP" at once | Matches the core loop (Results tallies XP). Level-ups mid-run would change max HP between rooms, which is harder to read. |
| 2026-09-28 | Attribute points are spent on the results screen; Focus is locked until kept powers exist | The design names no place to spend points before the Shrine (M4). Focus does nothing without powers, so a point spent there now would be wasted. |
| 2026-09-28 | Weapon mastery starts at 1; mastery n (2 to 10) needs `150 * n^1.4` total | GDD said "1 to 10" and "n requires 150 * n^1.4", which disagree at n = 1. Tallied on results; unlocks wait for M8 weapons. |
| 2026-09-28 | Mid-run save: every room load writes `run_slot_0.json`; Esc is now Save and quit (replaces "Esc leaves to the title, no confirm") and the title shows Continue run | Room boundaries per ARCHITECTURE 10. A quit restarts the room, but HP and flasks are saved no higher than at the quit and the room's loot drops again, so quitting is never a free heal or loot farm. |
| 2026-09-28 | Feel pass: turning against your motion brakes at acceleration + friction; swings ease from run speed instead of snapping; the move stick sets facing only past half tilt; a released right stick keeps its aim 0.25 s; a cursor within 6 px keeps the last aim; an attack press during the finisher stays buffered | Owner: movement and fighting "clunky", aiming "not the best", hero "not predictable". Causes found in code: a full reversal took 0.2 s (slidey), a swing cut run speed to 66 px/s on its first frame, letting go of the stick could turn the hero so the next swing went the wrong way, a flick-aim was forgotten the instant the stick was released, and a press during the finisher was used up and did nothing. Tests added for each; all fail on the old code. |
| 2026-09-28 | M3 split into 3 PRs: (1) powers, level 1 abilities, statuses, HUD slots, keep/merge rules; (2) level 3/5 upgrades, shard costs and leveling, Focus; (3) boss orbs and the keep screen | Same one-feature-per-PR workflow; the owner can judge how each power feels before upgrades and costs are tuned around them. Until PR 3 powers are tried in the Tuning room only. |
| 2026-09-28 | Abilities are `Ability` scripts picked by `PowerData.ability_script` (like `EnemyData.ai_script`), not ability scenes; effects are small reusable scenes (`PowerProjectile`, `PowerBurst`, `BramblePatch`) | A new power that fits an existing ability type is a `.tres` only. Per-cast state lives in the spawned effect, so an Ability needs none. ARCHITECTURE updated. |
| 2026-09-28 | Status numbers the GDD left open: Chill lasts 3 s, stagger bar 60 (bosses 250), Stone's burst adds 60 (stuns a regular enemy in one burst), a freeze on a boss adds 40 stagger, a root adds 30 at most once per (halved) root duration | GDD 7.3 gave effects but not these. A Bramble patch pulses 4 times a second, so without the once-per-window rule it would stun a boss in 2 s. |
| 2026-09-28 | Freeze and stun interrupt the enemy's current move (bosses too); a stun waits while Mother Toad is airborne | Pausing an AI mid-telegraph would let an attack land with no warning after the stun. Interrupting is the existing hit-stun path and always fair. |
| 2026-09-28 | Bulwark bursts when the shield breaks or after 4 s; a fully soaked hit does not stagger the hero | CONTENT says "absorbs 30 for 4 s, then bursts" without saying what a break does. Bursting on break rewards blocking a big hit. A hit that does no HP damage should not interrupt the hero. |
| 2026-09-28 | Bramble grows at the hero's feet (not at the aim point) | It heals the hero only while inside, so it is a zone to fight in. Casting it where the hero stands keeps it simple with a stick. |
| 2026-09-28 | Casting has a 0.12 s wind-up at half speed; dodge or a hit cancels it without spending the cooldown; a power can cancel swing recovery | A small commitment makes casts readable without feeling sluggish; losing a cooldown to a hit would feel unfair. |
| 2026-09-28 | Power hits use their own `CombatStats` (crit and Focus, no weapon tier or Might) | GDD 4.1 splits Might (weapon) from Focus (powers). Separate hitboxes also keep power damage out of weapon mastery. |
| 2026-09-27 | Prototype uses 4 powers (Fire, Frost, Growth, Stone) and 4 villagers (Smith, Farmer, Guard, Healer) | 16 combos is enough to test the Choice without heavy content cost. |

## Rejected ideas (do not re-propose without new info)

All checked by web search on 2026-09-27. See `docs/RESEARCH.md` for sources.

| Idea | Already done by |
|---|---|
| Jump arcs become platforms / nested wearable allies / camera-steering | Rejected by user as existing or too complex |
| Invisible protagonist inferred from surroundings | Rain (2013) |
| Stats from NPC beliefs / rumors | Persona 2 Rumor system |
| Companions imitate past play | Hades "Dark Zagreus" mod, MimickA |
| Mentor trains autonomous apprentice | Autonomous Hero, Princess Maker |
| Playthrough becomes myths in others' worlds | Tides of Tomorrow, NetHack bones |
| Gold is health | Rogue Fortune, Life Pact |
| Age per room | Aligeon, 10 Seconds Old, Sifu |
| Light radius is health | Several jam games |
| Reverse leveling | The Backwards RPG, Apostasy, Nox Inverta |
| Become what killed you | Lost in Prayer |
| Play as sentient sword | WeaponBound |
| Hero by day, monster by night | Dungeon Life (Roblox) |
| Sidekick of the real hero | Help the Hero |
| XP only for first-time actions | itch.io game |
| Mercenary bidding | Band of Mercenaries |

Runner-up ideas still considered original (keep for later or a future project): **Double or Nothing** (bet on your own performance each room), **Forget Me** (memories are currency).

## Open questions

- Frost up close: all 3 shards hitting one enemy is an instant freeze. Intended as a risk-for-reward, but watch whether it makes Frost the obvious keep (pillar 1).
- Power reward pool: Mossy Hollow's pool in CONTENT is Growth, Wind, Stone, but Fire and Frost only appear in later regions, which do not exist in the prototype. Proposal for M3 PR 3: the prototype Mossy Hollow offers all 4 [P] powers.

- Save and quit restarts the current room with full enemies. It cannot heal or duplicate loot, but a hero about to lose a fight can quit and retry it at the same HP. Acceptable for now (Hades works the same); revisit if playtests abuse it.

- Power Shard economy: with bosses a full run gives 10 to 11 shards (GDD 15.6) vs the 15.3 target of 4 to 6. Lower the per-source numbers or raise the target when shard costs exist (M3).
- Final title. Candidates: Pass It On, Hand-Me-Down Hero, Heirloom, The Giving Blade.
- Art direction specifics (palette, reference games). Proposed: warm cozy village vs saturated dangerous dungeons.
- Should failed runs still tick villager training? Current answer: yes (training counts runs attempted, not runs won). Revisit after playtest.
- Is 6 runs to Master the right pace? Tune in M5 playtests.
- Perfect dodge slow-motion (GDD 7.2): add before the Fusion meter (M6) if playtests want it.
- Online multiplayer tech: Godot high-level multiplayer over ENet vs Steam networking. Decide at M10.
- Platform targets beyond PC (Steam Deck verified is a goal; Switch-class consoles later).

## Session log

- **2026-09-28 (M3 PR 1):** Powers and statuses. `PowerData` + 4 powers (Fire Ember Bolt, Frost Shard, Stone Bulwark, Growth Bramble), `Ability` base and 4 ability scripts, effect scenes (`PowerProjectile`, `PowerBurst`, `BramblePatch`, `StoneShield`), hero Cast state, `PowerLoadout`, `PowerRules`, `GiftSystem` (keep, merge, release), `KeptPower` saved in `HeroState`, `StatusEffects` (burn, chill/freeze, root, stagger/stun, boss rules) wired through hurtboxes to enemies and dummies, `StatusBadge` pips and stagger bar, HUD power slots with cooldowns, Tuning room menu toggles powers (3 slot cap). `HealthComponent.shield`. 309 tests pass, no warnings, boot clean, checked with xvfb screenshots (slots cooling down, vine patch, frost fan, chill pip). Questions for the owner: does each power feel different in a fight? Is the 0.12 s cast wind-up noticeable or does it feel instant? Is the Frost point-blank freeze too strong? Does Bulwark's burst feel like a reward for blocking? Is Bramble useful, or too small (40 px)? Can you read the status pips and the stagger bar? Are the power slots (bottom left) clear, with the key under each?

- **2026-09-28 (combat feel pass):** Owner feedback: speed fine, but movement and fighting feel clunky, aim is not the best, the hero is not predictable. Fixes: `Hero.steer` (reversals brake at acceleration + friction, 0.1 s instead of 0.2 s), attack keeps momentum and adds the lunge on top, facing from the move stick only past half tilt (`Hero.FACE_MIN_TILT`), right stick aim held 0.25 s after release and a mouse dead zone of 6 px (`LocalInputSource`), finisher no longer swallows an attack press. Checked that Godot keeps quick taps during hit-stop (probe), so input polling was left alone. 269 tests pass, no warnings, boot clean. Questions for the owner: do turns and swings feel smoother? Does the hero now attack where you expect with the controller? Does a flick of the right stick then attack go where you flicked? Anything still feel off (describe the moment: what you pressed, what you expected, what happened)?

- **2026-09-28 (M2 PR 4):** XP, results screen, death rules and mid-run save. `ProgressionSystem` (XP curve, levels, attribute points, Might/Vigor stats, mastery curve), `HeroState` and `ProfileState` saved to slot 0 (loaded at boot), `EconomySystem` (keep 50% on a fall), `RunEnd` + `RunSummary`, `results.tscn` (XP bar, level-up, mastery, loot found vs kept, spend points on Might or Vigor), mid-run save on every room load, Esc is Save and quit, title shows Continue run and a level line. `Hero.apply_progress` applies level and attributes. 263 tests pass, no warnings, boot clean, checked with xvfb screenshots (results after a fall and after a clear, title with Continue run) and a real-router run (clear gives +15 XP, a fall banks 23 coins as 11 and lands on Results). Questions for the owner: does a full run land in 12 to 15 minutes? Does keeping half on a fall feel fair or too harsh? Is the results screen clear at a glance? Is Might vs Vigor a real choice? Does Save and quit plus Continue run work on your machine?

- **2026-09-27 (M2 PR 3):** Mother Toad and the Warden of Roots (phase 1). `BossData`, pure `BossPattern` (move order, enrage), `BossAI`, `MotherToadAI` (tongue pull, belly flop leap), `WardenAI` (seed volley fan, root walls, root slam), `RootWall` scene, boss bar on the HUD, "Mini-boss: / Boss:" banners, open boss arenas. Stand-in encounters removed. Tuning room menu can start either boss. Fixed arrows flying through walls (non-monitorable areas miss static bodies). 229 tests pass, no warnings, boot clean, checked with xvfb screenshots (tongue lane, flop ring, volley fan, root wall lane). Questions for the owner: is the tongue pull fair or does it feel like a cheap grab? Is the toad's landing pause long enough to punish? Is the Warden too easy to stand next to, or the slam too punishing? Are root walls readable before they burst? Does a boss take about the right time (target: under a minute or so each)?

- **2026-09-27 (M2 PR 2):** Drops, pickups and the other room types. `Wallet` (per hero in `RunState`), `DropTable`/`DropEntry`, pure `LootRoller`, `Pickup`, HUD loot line (coins, Wood, Crystal, shards). Every enemy drops loot; Treasure rooms have a chest; Merchant sells a flask, a heal and a shard; Event rooms (`EventData`, pure `EventResolver`) with Mossy Shrine and Wishing Well. Elites: Elder Boar (3 charges in a row) and Spore Witch (`SummonerAI`), gold outline, "Elite: name" banner. `RestSpot` became `InteractSpot`. Also fixed the red `main` test after the owner's balance edit. 205 tests pass, no warnings, boot clean, checked with xvfb screenshots (merchant, event, treasure loot, elite room). Questions for the owner: are the Merchant prices tempting or too steep? Do the events feel like a real risk? Is the Elder Boar's third charge fair? Is the Spore Witch too much with a Boar beside her? Does loot flying to you after a fight feel good?

- **2026-09-27 (controls remapping):** Owner asked where the map button is (Back / View on Xbox, Share or Create on PlayStation, Minus on Switch, Tab on keyboard) and for in-game remapping. Added pure `InputBindings` (rebind with swap, save and load, input names, hints), the Controls menu (title > Controls: pick a slot, press the new input within 5 s; Reset to defaults), boot loading, and live hints in all rooms. 168 tests pass, no warnings, boot clean, menu checked with an xvfb screenshot.

- **2026-09-27 (tuning room):** Owner asked for a separate tuning level driven by the controller, with results that can go to GitHub. New Tuning room on the title (dummies, a sparring dummy, Spawn enemies from the menu). `TuningPanel` is now a pause menu: Start opens it, D-pad changes numbers (RB x5), X resets, A runs Save results / Reset all / Spawn enemies / Back to title, B closes. Save results updates only the changed lines of `data/balance/balance_default.tres` (commit in GitHub Desktop), copies a summary to the clipboard and writes `user://tuning_results.txt`. 150 tests pass, no warnings, boot clean, menu checked with an xvfb screenshot.
- **2026-09-27 (M2 PR 1):** Floor maps and room flow. `RegionData` (Mossy Hollow: 3 floors, 5 to 7 rows, 2 to 3 rooms per row, room weights, encounter pools), pure `RunGenerator`, `FloorMap`, `MapRoom`, `RunState` in `GameState.run`. One `room.tscn` builds the corridor, fights (seeded pillar layouts and encounters), Rest (heal 30% or +1 flask) and signposts for Treasure, Merchant and Event. Doors in the top wall show the next rooms' types and stay barred until a fight is won. Floor exits lead down; the Warden stand-in ends the run. `RunMap` overlay (Tab / Back). Title has "Start a run". 3 new Mossy encounters plus stand-ins for elite and bosses. 140 tests pass, no warnings, boot clean, checked with xvfb screenshots (corridor, doors, fight, map, rest, stairs). Questions for the owner: is a floor too long or too short? Is the map readable at a glance? Do the doors make the next room clear enough? Does walking to the top wall to leave feel fine?

- **2026-09-27 (M1 PR 3):** Gamepad feel. `AimAssist` (stick swings turn toward the target nearest the aim line), rumble on hits and when hurt (`InputSource.rumble`, scaled by `rumble_strength`), stamina bar blinks red when a dodge is denied, `Hero.apply_balance()` for live changes. F4 `TuningPanel` autoload for live tuning. 114 tests pass, no warnings, boot clean, panel checked with an xvfb screenshot. Rumble and aim assist could not be felt in the cloud. Questions for the owner: does the dodge feel responsive on the pad? Is aim assist noticeable or too sticky? Is rumble too strong? Does drinking mid-fight feel risk-free (flask rule from PR 1)?
- **2026-09-27 (gamepad A fix):** Owner reported A does nothing on the title. Godot 4.7's default `ui_accept` has no gamepad button; `project.godot` now adds A (Enter and Space kept). Tests for the binding and for A pressing a focused title button.
- **2026-09-27 (M1 PR 2):** Enemies and waves. `EnemyData`, one `Enemy` scene, `SwarmAI`, `ChargerAI`, `RangedAI`. Sproutling (splits into 2 Seedlings), Tusk Boar (lane telegraph, charge, stuns on walls, not interrupted by hits), Thorn Archer (keeps distance, shot lane, arrows leave thorn patches on a miss). Enemy death animation. `EncounterData`/`WaveData`, `WaveDirector` with spawn markers, pure `WaveTracker`, `EventBus.room_cleared`. New Wave room (3 waves) on the title. Hero dodges through enemies. Numbers in GDD 15.5. 93 tests pass, no warnings, boot clean, checked with xvfb screenshots (lanes, thorn patch, waves advancing).
- **2026-09-27 (debug overlay):** Owner's Output showed only editor undo lines ("Set mouse_filter" etc.), so they edited properties in the Inspector; nothing was pushed. Added the F3 `DebugOverlay` so the owner can see on their machine where clicks go and paste the Output lines.
- **2026-09-27 (title click):** Owner reported mouse clicks not registering on the title. Could not reproduce (real clicks work in xvfb and in a new GUT test). Fixed a real SceneRouter bug found while checking: a failed scene load waited forever and locked the router. Added title click tests. Likely cause on the owner's side: the editor's embedded Game tab in a selection mode instead of Input mode. Waiting on the owner's answer.
- **2026-09-27 (warnings fix):** Owner reported 15 editor warnings (EventBus unused signals, `count` shadowing in ContentDB). Fixed those plus a hidden one (`text` shadowing Label.text in DamageNumber). Added `tools/check_warnings.gd` and a CI step so warnings fail the build.
- **2026-09-27 (M1 PR 1):** Hero combat core: movement with acceleration, mouse/stick aim, 3-hit sword combo with input buffer and dodge-cancel, dodge with i-frames and stamina, flasks, hurt and death. Components (Health, Hitbox, Hurtbox, Knockback, Status, StateMachine, InputSource), CombatMath, StaminaPool, FlaskPouch, BalanceData, WeaponData/AttackData. Game feel: hit flash shader, hit-stop, camera shake, damage numbers, telegraph ring. Test room with 2 training dummies and a sparring dummy that telegraphs a slam; HUD with HP, stamina, flasks; title has a Combat test button. 63 tests pass, boot clean, verified with xvfb screenshots (found and fixed a hit-stop freeze bug that way).
- **2026-09-27 (M0):** Created the Godot project, folders, input map, 6 autoloads, placeholder boot and title scenes, GUT with 18 passing tests, CI workflow. Verified locally in a cloud session with Godot 4.7.2 headless: import clean, all tests pass, game boots to the title screen.
- **2026-09-27:** Brainstormed and researched ~20 concepts, settled on Pass It On. Wrote CLAUDE.md, MEMORY.md, docs/GDD.md, docs/CONTENT.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, docs/RESEARCH.md.
