# MEMORY.md

Persistent project memory. Read at the start of every session, update at the end.

## Current status

- **Phase:** M0 done. M1 (combat core) in progress, split into 3 PRs. PR 1 (hero core) and PR 2 (enemies, waves, room clear) merged. Owner played PR 2: everything worked except gamepad A on the title (fixed in a small PR).
- **Next step:** M1 PR 3: feel and tuning, checked with a gamepad.
- **Last updated:** 2026-09-27 (M1 PR 2)

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

- Final title. Candidates: Pass It On, Hand-Me-Down Hero, Heirloom, The Giving Blade.
- Art direction specifics (palette, reference games). Proposed: warm cozy village vs saturated dangerous dungeons.
- Should failed runs still tick villager training? Current answer: yes (training counts runs attempted, not runs won). Revisit after playtest.
- Is 6 runs to Master the right pace? Tune in M5 playtests.
- Perfect dodge slow-motion (GDD 7.2): add before the Fusion meter (M6) if playtests want it.
- Online multiplayer tech: Godot high-level multiplayer over ENet vs Steam networking. Decide at M10.
- Platform targets beyond PC (Steam Deck verified is a goal; Switch-class consoles later).

## Session log

- **2026-09-27 (gamepad A fix):** Owner reported A does nothing on the title. Godot 4.7's default `ui_accept` has no gamepad button; `project.godot` now adds A (Enter and Space kept). Tests for the binding and for A pressing a focused title button.
- **2026-09-27 (M1 PR 2):** Enemies and waves. `EnemyData`, one `Enemy` scene, `SwarmAI`, `ChargerAI`, `RangedAI`. Sproutling (splits into 2 Seedlings), Tusk Boar (lane telegraph, charge, stuns on walls, not interrupted by hits), Thorn Archer (keeps distance, shot lane, arrows leave thorn patches on a miss). Enemy death animation. `EncounterData`/`WaveData`, `WaveDirector` with spawn markers, pure `WaveTracker`, `EventBus.room_cleared`. New Wave room (3 waves) on the title. Hero dodges through enemies. Numbers in GDD 15.5. 93 tests pass, no warnings, boot clean, checked with xvfb screenshots (lanes, thorn patch, waves advancing).
- **2026-09-27 (debug overlay):** Owner's Output showed only editor undo lines ("Set mouse_filter" etc.), so they edited properties in the Inspector; nothing was pushed. Added the F3 `DebugOverlay` so the owner can see on their machine where clicks go and paste the Output lines.
- **2026-09-27 (title click):** Owner reported mouse clicks not registering on the title. Could not reproduce (real clicks work in xvfb and in a new GUT test). Fixed a real SceneRouter bug found while checking: a failed scene load waited forever and locked the router. Added title click tests. Likely cause on the owner's side: the editor's embedded Game tab in a selection mode instead of Input mode. Waiting on the owner's answer.
- **2026-09-27 (warnings fix):** Owner reported 15 editor warnings (EventBus unused signals, `count` shadowing in ContentDB). Fixed those plus a hidden one (`text` shadowing Label.text in DamageNumber). Added `tools/check_warnings.gd` and a CI step so warnings fail the build.
- **2026-09-27 (M1 PR 1):** Hero combat core: movement with acceleration, mouse/stick aim, 3-hit sword combo with input buffer and dodge-cancel, dodge with i-frames and stamina, flasks, hurt and death. Components (Health, Hitbox, Hurtbox, Knockback, Status, StateMachine, InputSource), CombatMath, StaminaPool, FlaskPouch, BalanceData, WeaponData/AttackData. Game feel: hit flash shader, hit-stop, camera shake, damage numbers, telegraph ring. Test room with 2 training dummies and a sparring dummy that telegraphs a slam; HUD with HP, stamina, flasks; title has a Combat test button. 63 tests pass, boot clean, verified with xvfb screenshots (found and fixed a hit-stop freeze bug that way).
- **2026-09-27 (M0):** Created the Godot project, folders, input map, 6 autoloads, placeholder boot and title scenes, GUT with 18 passing tests, CI workflow. Verified locally in a cloud session with Godot 4.7.2 headless: import clean, all tests pass, game boots to the title screen.
- **2026-09-27:** Brainstormed and researched ~20 concepts, settled on Pass It On. Wrote CLAUDE.md, MEMORY.md, docs/GDD.md, docs/CONTENT.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, docs/RESEARCH.md.
