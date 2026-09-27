# MEMORY.md

Persistent project memory. Read at the start of every session, update at the end.

## Current status

- **Phase:** M0 (project setup) done, in review as a draft PR into `main`.
- **Next step:** Milestone M1 (combat core) in `docs/ROADMAP.md`, once the owner has opened the project locally.
- **Last updated:** 2026-09-27

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
- Moving to local development: Claude Code on Windows in the repo folder, with the Godot MCP server `@coding-solo/godot-mcp` (via npx, `GODOT_PATH` set to the console exe) so Claude can run the game and read errors.
- Local workflow: still use a branch plus PR into `main` for each change, so CI runs and the owner reviews before merging.

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
- Online multiplayer tech: Godot high-level multiplayer over ENet vs Steam networking. Decide at M10.
- Platform targets beyond PC (Steam Deck verified is a goal; Switch-class consoles later).

## Session log

- **2026-09-27 (M0):** Created the Godot project, folders, input map, 6 autoloads, placeholder boot and title scenes, GUT with 18 passing tests, CI workflow. Verified locally in a cloud session with Godot 4.7.2 headless: import clean, all tests pass, game boots to the title screen.
- **2026-09-27:** Brainstormed and researched ~20 concepts, settled on Pass It On. Wrote CLAUDE.md, MEMORY.md, docs/GDD.md, docs/CONTENT.md, docs/ARCHITECTURE.md, docs/ROADMAP.md, docs/RESEARCH.md.
