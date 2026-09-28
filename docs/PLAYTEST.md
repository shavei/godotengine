# Pass It On: playtest build

Thank you for playing! This is an early prototype: placeholder art, no sound, one region.
We want to know one thing above all: **is the Choice fun?** Every power you earn, you can keep, or give to a villager forever.

## Start the game

| System | How |
|---|---|
| Windows | Unzip the folder and run `PassItOn.exe`. Windows may warn that the app is unknown (it is not signed yet): press **More info**, then **Run anyway**. |
| Linux | Unzip the folder and run `./PassItOn.x86_64` (if it does not start: `chmod +x PassItOn.x86_64`). |

A gamepad (Xbox layout) or keyboard and mouse both work. **Controls** on the title screen shows and changes every button.

## Turn on the playtest log (please!)

1. On the title screen, press **Playtest log: off** (bottom left). It now says **on**. The choice is saved.
2. Play as usual. The game writes one small file per session. Nothing is sent anywhere.
3. When you are done, press **Open log folder** on the title screen and send us every `session_*.json` file in it.

The files hold only what happened in the game: each Choice (which power, keep or give, to whom, and how long you thought about it), each run (how long, cleared or fell, what hit you last, which rooms), villager rank-ups, Techniques learned and Renown levels. No names, no system information.

Where the folder is, if the button does not open it:

| System | Folder |
|---|---|
| Windows | `%APPDATA%\Godot\app_userdata\Pass It On\metrics` |
| Linux | `~/.local/share/godot/app_userdata/Pass It On/metrics` |

Your save is in the `saves` folder next to it. **New game** on the title starts over.

## What to try

- Play for about 2 hours, in one sitting or several.
- Every run ends with a new power. Keep it, or give it to a villager. Watch what the villager does with it.
- Talk to villagers, check the notice board, press the Map button in the village to see your hero.

## Questions (send answers with your log files)

1. Did you hesitate on the Choice? Why?
2. Did you ever regret a gift? A keep?
3. When a villager reached Master, how did it feel?
4. Did you notice the village change?
5. What made you want one more run? What made you stop?

Anything else you noticed (bugs, confusing moments, what you liked) is welcome too.

---

## For the developer

- **Make a build:** GitHub > Actions > **Playtest builds** > Run workflow. The Windows and Linux zips appear on the run's page. Pushing a tag like `v0.5.0` also puts them on a GitHub release. Locally: Godot > Project > Export (presets for both are in `export_presets.cfg`; export templates for 4.7.2 are needed).
- **Read the logs:** put every tester's `session_*.json` in one folder and run `godot --headless -s tools/metrics_report.gd -- <folder>`. It prints the prototype gate numbers (powers given 40% to 60%, median Choice time 10 to 40 s), runs, causes of death, rank-ups and Techniques.
- Release builds hide the test rooms on the title and have no debug tools (F3, F4, console).
