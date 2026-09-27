# CLAUDE.md

Guidance for Claude (and any contributor) working in this repository.

## What this project is

**Pass It On** (working title) is a 2D top-down action roguelite RPG with a village-building meta loop, built in **Godot 4**.

The one-sentence pitch: **Every power you earn, you can keep, or give to a villager forever.** Powers given away are trained by the villager and eventually come back to the player as permanent Techniques, so both the hero and the village grow.

Single player first. Multiplayer (co-op runs, village visits, raid help) is optional and comes later, but the architecture must not block it.

## Read these first

| File | What it holds |
|---|---|
| `MEMORY.md` | Project memory: current status, decisions and why, rejected ideas, user preferences, open questions. **Read at the start of every session. Update at the end.** |
| `docs/GDD.md` | Game design document: every system, rule and number. The source of truth for design. |
| `docs/CONTENT.md` | Content tables: powers, villagers, all 64 villager+power combos, 28 fusions, weapons, regions, enemies, bosses. |
| `docs/ARCHITECTURE.md` | Technical plan: Godot project layout, autoloads, data resources, systems, save format, multiplayer readiness, testing. |
| `docs/ROADMAP.md` | Milestones M0 to M12 with tasks, done criteria and playtest questions. |
| `docs/RESEARCH.md` | Prior-art research and design lessons, with sources. |

If code and docs disagree, stop and ask, or fix the doc in the same change. Never let them drift silently.

## Design pillars (check every feature against these)

1. **The Choice is the heart.** Keep or give must be a hard, interesting decision every time. Anything that makes the choice obvious (always keep, always give) is a bug.
2. **Both sides grow.** The player and the village each have their own progression. Giving is an investment, not a sacrifice.
3. **Depth from interaction, not from rule count.** Every system must be explainable in one sentence. Depth comes from how systems combine.
4. **See your choices.** Every gift must visibly change the village (sprite, building, shop, NPC line).
5. **Short runs, long arc.** A run is 12 to 15 minutes. The full game is 25+ hours.

## Tech stack and conventions

- **Engine:** Godot **4.7.2** (standard build, not .NET). Pinned: do not upgrade without logging it in `MEMORY.md`. **Renderer:** Compatibility (GL). **Language:** GDScript with static typing everywhere (`var hp: int = 10`, typed function signatures, typed arrays).
- **Resolution:** 640x360 base, stretch mode `canvas_items` with integer scaling (1280x720 default window; text and UI render at full screen resolution, pixel art scales by whole numbers), 32x32 tiles, pixel art. `texture_filter = nearest`.
- **Naming:**
  - Files and folders: `snake_case` (`gift_system.gd`, `power_fire.tres`).
  - Classes: `PascalCase` with `class_name`.
  - Signals: past tense verbs (`power_given`, `villager_ranked_up`).
  - Constants and enums: `UPPER_SNAKE_CASE`.
- **Data-driven content.** Powers, villagers, combos, fusions, weapons, enemies and regions are custom `Resource` files (`.tres`) under `data/`. Game code never hardcodes content by name. Adding a power or villager should need **zero code changes**.
- **Rules live in pure logic classes** (`RefCounted`, no nodes) under `scripts/systems/` so they can be unit tested headless. Nodes and scenes call into them.
- **Communication:** Use the `EventBus` autoload for cross-system signals. Avoid `get_node("../../..")` chains. Components talk to their owner via signals.
- **No per-player state in autoloads.** Anything that belongs to "the player" is keyed by a `player_id`, so co-op can be added later without a rewrite (see `docs/ARCHITECTURE.md`, Multiplayer readiness).
- **Composition over inheritance** for actors: `HealthComponent`, `HitboxComponent`, `HurtboxComponent`, `StatusComponent`, `StateMachine`.
- **Scenes:** one root script per scene, same name as the scene (`player.tscn` + `player.gd`).
- **Commit `.import` and `.uid` files**, ignore `.godot/`.

## Testing

- Unit tests use **GUT 9.7.1** (the release for Godot 4.7) in `tests/unit/`, configured by `.gutconfig.json`. Every rule in `scripts/systems/` gets tests (gift rules, training timers, fusion eligibility, neighbor bonuses, save/load round trip). Every new scene goes in `tests/unit/test_scenes.gd`.
- Commands (run from the repo root):
  - Import (needed once after clone or after adding assets): `godot --headless --import`
  - Tests: `godot --headless -s addons/gut/gut_cmdln.gd -gexit`
  - Boot check: `godot --headless --quit-after 180` (must print no errors)
- CI (`.github/workflows/tests.yml`) runs the same three steps on every push to `main` and every PR.
- Cloud sessions: Godot is not preinstalled. Download the Linux build from `https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` and put it on the PATH as `godot`.
- Before committing gameplay code: run the tests and the boot check, and launch the affected scene once.

## Writing rules

- **Never use the em dash character** in docs, comments, UI text, commit messages or chat replies. Use a colon, comma, parentheses or a new sentence instead. (User preference.)
- Keep docs plain and scannable: tables and short bullets over long paragraphs.
- UI text is warm and short. The village is a cozy place; the dungeons are the danger.

## Working agreements

- Work milestone by milestone from `docs/ROADMAP.md`. Do not start a later milestone's features early unless asked.
- The **prototype gate** (end of M5) decides whether the core Choice is fun. Do not build content breadth before that gate passes.
- When you make a design decision, add it to the Decisions log in `MEMORY.md` with the date and the reason.
- When numbers change during balancing, update `docs/GDD.md` (Balance section) in the same commit.
- Do not add features the design docs do not describe. Propose them in `MEMORY.md` under Open questions instead.
