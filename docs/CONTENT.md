# Pass It On: Content Tables

Companion to `docs/GDD.md`. Every row here becomes a `.tres` Resource under `data/` (see `docs/ARCHITECTURE.md`). Numbers are starting points for tuning.

Prototype subset (M3 to M5) is marked **[P]**.

---

## 1. Powers (8)

| Power | Color / icon shape | Ability (level 1) | Level 3 upgrade | Level 5 upgrade | Status | Cooldown | Found in |
|---|---|---|---|---|---|---|---|
| **Fire [P]** | Orange / flame | **Ember Bolt:** fireball, 20 dmg | Explodes on impact (small area) | Leaves burning ground for 3 s | Burn | 4 s | Ember Mines |
| **Frost [P]** | Ice blue / snowflake | **Frost Shard:** 3-shard fan, 10 dmg each | Shards pierce | Frozen enemies shatter for area damage | Chill | 5 s | Frostpeak |
| **Storm** | Yellow / bolt | **Arc:** lightning jumps between 3 enemies, 15 dmg | Jumps to 5 | Every 3rd cast calls a sky strike | Shock | 5 s | Ember Mines, Gloam Marsh |
| **Stone [P]** | Brown / square | **Bulwark:** shield absorbs 30 dmg for 4 s, then bursts for 25 | Burst throws spikes in a ring | Shield reflects projectiles | Stagger | 8 s | Mossy Hollow, Ember Mines |
| **Growth [P]** | Green / leaf | **Bramble:** vine patch roots enemies, heals you 2 HP/s inside | Bigger patch, lasts longer | Roots deal damage and spread | Root | 7 s | Mossy Hollow, Gloam Marsh |
| **Wind** | Pale teal / swirl | **Gale:** cone gust, knockback, +30% move speed for 3 s | Wall impacts stun longer | Leaves a small cyclone that pulls | Knockback | 5 s | Mossy Hollow, Frostpeak |
| **Light** | Gold / sun | **Radiance:** short beam, 25 dmg | Beam heals you 10% of damage dealt | Cleanses your debuffs and blinds enemies 1 s | Radiant | 6 s | Frostpeak |
| **Shadow** | Violet / crescent | **Veil Step:** blink 4 tiles, next attack guaranteed crit | Leaves a decoy that draws aggro | 2 charges | Marked | 6 s | Gloam Marsh |

Raid spell (basic, used by powered villagers in raids): Fire firebomb, Frost ice patch, Storm lightning strike, Stone rock wall segment, Growth thorn patch, Wind gust pushback, Light healing pulse on buildings, Shadow decoy.

---

## 2. Villagers (8)

Names are placeholders. Base service works with no power.

| Job | Name | Workplace | Base service (no power) | Arrives |
|---|---|---|---|---|
| **Smith [P]** | Brann | Forge | Sells weapons (Iron to Mythic tiers) | Start |
| **Farmer [P]** | Tilly | Fields | +1 flask charge per run; supplies the Baker | Start |
| **Guard [P]** | Maren | Watchtower | Defends in raids; +1 tower | Start |
| **Healer [P]** | Osk | Clinic | 1 revive token per run (revive at 30%) | Renown 2 |
| **Miller** | Pim | Mill | Converts materials; small coin income per run (+30) | Renown 3 |
| **Baker** | Rosa | Bakery | Sells one meal per run (small buff, whole run) | Renown 4 |
| **Hunter** | Kestrel | Lodge | Reveals the next room type 2 steps ahead on the map | Renown 5 |
| **Scholar** | Elden | Library | Codex, Shrine lore; converts 20 materials (any mix) into 1 Power Shard | Renown 6 |

---

## 3. Villager + power combos (64)

Format: **Novice** service / **Adept** upgrade / **Master Technique** (permanent player passive).

### 3.1 Smith
| Power | Novice | Adept | Master Technique |
|---|---|---|---|
| Fire [P] | Sells Fire infusion: weapon hits 15% Burn | 30% Burn; Runed tier unlocks one Forge level early | **Ember Step:** your dodge leaves a fire trail |
| Frost [P] | Frost infusion: 15% Chill | 30% Chill; armor that reduces damage 10% | **Cold Temper:** perfect dodges Chill nearby enemies |
| Storm | Storm infusion: 15% Shock | 30% Shock; +10% attack speed | **Live Wire:** every 5th weapon hit chains lightning |
| Stone [P] | Stone infusion: +25% stagger damage | +50%; armor +15% max HP | **Anvil Skin:** the first hit each room deals 50% less |
| Growth [P] | Self-mending gear: +5% dmg per room without being hit (max 25%) | Max 40% | **Living Steel:** killing blows heal 1 HP |
| Wind | Light weapons: +10% attack speed | +20%, dash attack range +30% | **Featherweight:** attacking does not slow your movement |
| Light | Blessed weapons: +20% dmg to elites and bosses | +35% | **Gleam:** your crits make enemies Radiant |
| Shadow | Serrated weapons: +10% crit chance | +20% | **Backstab:** hits from behind always crit |

Prototype note (M4 PR 2): each Smith service is bought once per hero at the Forge (100 coins) and then works every run; "sells armor" upgrades come with the Adept rank. The Growth row counts fight rooms cleared without being hit; any hit resets it.

### 3.2 Farmer
| Power | Novice | Adept | Master Technique |
|---|---|---|---|
| Fire [P] | Roasted harvest: flasks heal +25% | +50% | **Hearth Heart:** drinking a flask gives 5 s of Burn on hit |
| Frost [P] | Cold storage: +1 flask | +2 flasks | **Second Serving:** your first flask each floor is not used up |
| Storm | Rain-fed fields: region materials +20% | +40% | **Charged Soil:** standing still 1 s makes your next power deal +30% |
| Stone | Terraces: +40 coins per run | +80, Wood +10 per run | **Rooted Stance:** you cannot be knocked back while attacking |
| Growth [P] | Overnight crops: +2 flasks | +3 flasks, flasks also heal over time | **Regrowth:** regenerate 1 HP per second out of combat |
| Wind | Windmill irrigation: Miller and Baker services +20% | +40% | **Tailwind:** +10% move speed |
| Light | Sun crops: flasks cleanse debuffs | And +10 max HP | **Sunlit:** above 80% HP you deal +10% damage |
| Shadow | Moon mushrooms: flasks make enemies lose track of you 3 s | 5 s | **Night Forager:** enemies drop healing orbs 2x as often |

### 3.3 Guard
| Power | Novice | Adept | Master Technique |
|---|---|---|---|
| Fire [P] | Burning arrows from towers in raids | Towers ignite the ground | **Rally Flame:** below 30% HP your powers deal +30% |
| Frost [P] | Ice walls block one raid gate for 30 s | Two gates | **Hold the Line:** enemies that hit you are Chilled |
| Storm | Tesla tower in raids | Chains to 4 enemies | **Static Guard:** getting hit Shocks the attacker |
| Stone [P] | Walls +50% HP in raids | +100%, walls regenerate | **Stoneguard:** +20 max HP |
| Growth [P] | Thorn hedges damage raiders | Hedges also root | **Thornmail:** melee attackers take 5 damage |
| Wind | Watchtower sees raids 1 run earlier; runs start with elite rooms marked | Treasure rooms also marked | **Sentinel's Step:** dodge distance +30% |
| Light | Signal fires: villagers start raids with a +20% damage buff | +40% | **Dawn Watch:** first 10 s of each room you take 30% less damage |
| Shadow | Ambush squad in raids (flanking attacks) | Larger squad | **Counterstrike:** after a perfect dodge your next attack deals double |

### 3.4 Healer
| Power | Novice | Adept | Master Technique |
|---|---|---|---|
| Fire [P] | Revives explode in fire around you | Revive at 50% HP | **Fever:** below 50% HP, +20% attack speed |
| Frost [P] | Numbing salve: -10% damage taken on boss floors | -20% | **Cold Blood:** dropping below 30% HP slows time briefly (once per room) |
| Storm | +1 revive token | +2 | **Jolt:** getting hit has a 10% chance to reset a power cooldown |
| Stone [P] | Bone setting: +20 max HP | +40 | **Iron Bones:** immune to stagger and knockback |
| Growth [P] | Herbal care: heal 3 HP per room cleared | 6 HP | **Second Wind:** heal 15% on entering each floor |
| Wind | Fresh air: debuffs on you last 30% shorter | 50% | **Deep Breath:** stamina regen +30% |
| Light | Blessing: +1 revive token, revives cleanse | +2 | **Grace:** once per floor, a fatal hit leaves you at 1 HP |
| Shadow | Leech therapy: 2% lifesteal | 4% | **Siphon:** kills with a power heal 3 HP |

Prototype note (M4 PR 2): every Mossy Hollow floor ends in a boss fight, so Frost's "boss floors" means the mini-boss and region boss rooms. Revive tokens are used by a lethal hit and carry between rooms.

Prototype note (M5 PR 2, Technique readings for the 16 [P] combos): each Technique is a `TechniqueData` in `data/techniques/`. "Perfect dodge" (Cold Temper) means a dodge that rolls through an attack. "Up close" attackers (Hold the Line, Thornmail) are enemies whose own attack hit you, not arrows or thorn patches. Rooted Stance also keeps a hit from breaking your swing, not only the knockback. Regrowth's "out of combat" means no enemy is alive in the room. Second Wind heals when you reach a floor (on floor 1 you are already full). Iron Bones means no knockback and no hurt stagger, and Fever's "attack speed" runs the whole swing faster.

### 3.5 Miller
| Power | Novice | Adept | Master Technique |
|---|---|---|---|
| Fire | Kiln: building costs -15% | -30% | **Furnace Core:** each power cast cuts other cooldowns by 0.5 s |
| Frost | Ice house: materials are never lost on death | Coins also | **Cool Head:** power cooldowns -10% |
| Storm | Lightning mill: +60 coins per run | +120 | **Dynamo:** dodging adds +5 to the Fusion meter |
| Stone | Grindstone: 10 Ore to 1 Power Shard | 6 Ore | **Whetted:** weapon damage +10% |
| Growth | Seed bank: Farmer service +25% | +50% | **Harvest:** elites drop +1 Power Shard |
| Wind | Windmill: all materials +25% | +50% | **Momentum:** consecutive hits without being hit add up to +20% damage |
| Light | Gilded mill: coins +30% | +60% | **Midas Touch:** treasure rooms give one extra reward |
| Shadow | Smuggler's cellar: merchant rooms 2x as common, prices -20% | -35% | **Black Market:** one free merchant item per run |

### 3.6 Baker (meal lasts the whole run; one meal per run)
| Power | Novice meal | Adept | Master Technique |
|---|---|---|---|
| Fire | Spicy Pie: +15% power damage | +25% | **Firebelly:** flasks give +20% damage for 5 s |
| Frost | Frosted Cake: +20 max HP | +40 | **Chill Out:** all healing +20% |
| Storm | Crackle Bread: +15% attack speed | +25% | **Sugar Rush:** after a power cast, +20% move speed for 2 s |
| Stone | Hearty Loaf: -15% damage taken | -25% | **Stuffed:** +1 flask |
| Growth | Garden Tart: 1 HP/s regen out of combat | 2 HP/s | **Well Fed:** max HP +10% |
| Wind | Airy Souffle: +15% move speed | +25% | **Light Step:** dodges cost 20% less stamina |
| Light | Honey Cake: +15% XP | +30% | **Nourished:** +10% XP permanently |
| Shadow | Midnight Snack: +15% crit chance | +25% | **Sneak Snack:** the first hit in each room deals double |

### 3.7 Hunter
| Power | Novice | Adept | Master Technique |
|---|---|---|---|
| Fire | Flare scouting: whole floor map revealed | Room contents revealed | **Predator:** +15% damage to enemies below 50% HP |
| Frost | Trapper bounties: a marked elite each run gives +2 shards | +4 | **Snare:** enemies you dodge through are Chilled |
| Storm | Storm bounty: beat the boss without flasks for bonus Crystal | More Crystal | **Quickdraw:** your first attack in each fight is instant and crits |
| Stone | Stone traps in raids | More traps | **Pitfall:** dodging leaves a trap that roots the first enemy |
| Growth | Tracker's herbs: bestiary shows enemy weaknesses | +10% damage to weaknesses | **Know Thy Prey:** +10% damage to enemy types you have killed 50 of |
| Wind | Falcon companion pecks enemies in runs | Falcon also fetches coins | **Hawk Eye:** ranged attacks +20% range and damage |
| Light | Lantern: secret rooms appear on the map | 2 secret rooms | **Keen Sight:** +10% crit chance |
| Shadow | Poacher: elites drop extra loot | More loot | **Silent Hunt:** enemies take 0.5 s longer to notice you; +30% damage to unaware enemies |

### 3.8 Scholar
| Power | Novice | Adept | Master Technique |
|---|---|---|---|
| Fire | Candlelit study: every villager +1 TP every 3 runs | Every 2 runs | **Quick Study:** weapon mastery XP +25% |
| Frost | Archive: Codex shows hints for undiscovered combos | Full previews | **Clear Mind:** power cooldowns -10% |
| Storm | Lecture hall: bosses drop +1 Power Shard | +2 | **Brainstorm:** every 4th power cast has no cooldown |
| Stone | Stone tablets: gifts start with +1 extra TP | +2 | **Foundation:** power levels cost 1 fewer shard each |
| Growth | Botany: new villagers arrive with 1 TP ready for their first gift | 2 TP | **Late Bloomer:** +2% damage per floor cleared this run |
| Wind | Correspondence: rumors reveal the next raid's composition (and powers async postcards in multiplayer) | Two raids ahead | **Swift Mind:** Fusion meter fills 20% faster |
| Light | Enlightenment: run XP +15% | +30% | **Insight:** see enemy HP and weaknesses; +5% crit |
| Shadow | Forbidden tomes: Curse rooms appear (take a curse for a big reward) | Better rewards | **Dark Knowledge:** +8% damage for each curse carried this run |

---

## 4. Fusions and Neighbor bonuses (28 pairs)

One table, two uses. The **player Fusion** is the ultimate when both powers are kept at level 3+. The **Neighbor bonus** is the village-wide effect when two adjacent villagers (Adept+) hold the pair.

| Pair | Player Fusion (ultimate) | Neighbor bonus (village) |
|---|---|---|
| Fire + Frost [P] | **Steam Burst:** scalding cloud, damage and blind | **Hot Springs:** +1 flask per run |
| Fire + Storm | **Plasma Lance:** long piercing beam | **Foundry:** building costs -15% |
| Fire + Stone [P] | **Magma Quake:** lava cracks spread across the room | **Kiln Works:** weapon prices -20% |
| Fire + Growth [P] | **Wildfire:** spreading flames; heal per burning enemy | **Ash Fields:** Farmer service +25% |
| Fire + Wind | **Firestorm:** moving fire tornado | **Bellows:** Smith weapons +10% damage |
| Fire + Light | **Solar Flare:** room-wide flash, heavy damage | **Lighthouse:** raid warnings 1 run earlier, raid rewards +25% |
| Fire + Shadow | **Hellfire Veil:** chain of blinks leaving fire | **Smoke Signals:** Hunter scouting also reveals treasure |
| Frost + Storm | **Hailstorm:** falling ice and lightning over an area | **Cold Storage:** materials never lost on death |
| Frost + Stone [P] | **Glacier Wall:** ice wall that crushes forward | **Ice Cellar:** Baker meals +25% |
| Frost + Growth [P] | **Frostbloom:** ice flowers freeze enemies and heal you | **Winter Garden:** flasks heal +20% |
| Frost + Wind | **Whiteout:** freezing blizzard cone | **Snow Drift:** raiders move 20% slower |
| Frost + Light | **Prism:** beam splits into 5 | **Crystal Hall:** +1 Power Shard per run |
| Frost + Shadow | **Black Ice:** invulnerable slide dash that freezes everything touched | **Still Night:** all villagers +1 TP every 4 runs |
| Storm + Stone | **Thunderquake:** shockwave rings that Shock and Stagger | **Lightning Rod:** tower damage +30% in raids |
| Storm + Growth | **Spring Rain:** healing rain that Shocks enemies | **Fertile Storms:** all materials +15% |
| Storm + Wind | **Tempest:** huge lightning cyclone | **Weathervane:** coins +20% |
| Storm + Light | **Judgment:** sky bolts strike every Radiant enemy | **Beacon Spire:** XP +10% |
| Storm + Shadow | **Blackout:** room goes dark, enemies lose you, your hits Shock | **Night Market:** merchant prices -15% |
| Stone + Growth [P] | **Ancient Grove:** summons a treant ally for 8 s | **Orchard Walls:** walls regenerate in raids |
| Stone + Wind | **Sandstorm:** blinding storm with chip damage | **Trade Road:** a merchant visits the village every run |
| Stone + Light | **Sanctuary:** dome that blocks all damage for 3 s | **Cathedral:** +1 Renown per raid won |
| Stone + Shadow | **Catacomb:** 3 stone shades fight for you | **Hidden Vault:** keep 100% coins on death |
| Growth + Wind | **Pollen Storm:** spores that Root and heal you | **Wildflower Meadow:** Baker meals give a second random buff |
| Growth + Light | **Bloom of Dawn:** heal over time, all enemies Radiant | **Sacred Grove:** +15 max HP |
| Growth + Shadow | **Nightshade:** poison fog that spreads between enemies | **Herbalist Den:** revives heal 25% more |
| Wind + Light | **Aurora:** zone of +30% speed and damage | **Kite Festival:** Renown gains +20% |
| Wind + Shadow | **Phantom Gale:** 6 rapid blink-slashes | **Whisper Network:** +1 Hunter bounty per run |
| Light + Shadow | **Eclipse:** all enemies slowed 80% for 3 s | **Twilight Pact:** all other Neighbor bonuses +25% |

**Resonance** (same power, adjacent, both Adept+): both villagers' services +25%. One entry per power in the Codex (8).

---

## 5. Weapons (4)

| Weapon | Style | Combo | Dash attack (M2) | Charged (M4) | Special (M6) | Finisher (M8) | Signature (M10) |
|---|---|---|---|---|---|---|---|
| **Sword [P]** | Balanced, 3-hit | 12 / 12 / 20 dmg | Lunge slash | Spin slash | Parry (0.2 s window, counter x2) | Execution on staggered | **Riposte Storm:** perfect parry triggers 5-hit flurry |
| **Spear** | Reach, pierce | 10 / 10 / 18, hits 2 in line | Vault strike | Thrown spear (returns) | Sweep (knockback) | Impale pins staggered enemy | **Skewer Line:** pierce every enemy in a line |
| **Bow** | Ranged | 8 per arrow, fast | Backstep shot | Charged piercing shot | Arrow rain | Point-blank crit on staggered | **Volley:** 7-arrow fan every 3rd charged shot |
| **Hammer** | Slow, heavy | 26 / 34, high stagger | Leap slam | Ground pound (area) | Throw hammer | Shatter (double damage on staggered) | **Earthbreaker:** every slam sends a shockwave |

---

## 6. Regions, enemies and bosses

Enemy archetypes: Chaser, Charger, Ranged, Ambusher, Tank, Summoner, Swarm, Bomber.

### 6.1 Mossy Hollow (region 1) [P]
- Palette: greens and browns, fireflies. Materials: Wood. Powers: Growth, Wind, Stone. (Prototype: the pool is Fire, Frost, Growth and Stone, the 4 [P] powers, until Wind and the other regions exist.)

| Enemy | Archetype | Twist |
|---|---|---|
| Sproutling | Swarm | Splits into 2 seedlings on death |
| Burrow Mole | Ambusher | Tunnels under you, pops up with a telegraph |
| Thorn Archer | Ranged | Arrows leave thorn patches |
| Tusk Boar | Charger | Stuns itself on walls (bait it) |
| Moss Golem | Tank | Heals in grass tiles |
| **Elite:** Elder Boar | Charger | Charges 3 times in a row |
| **Elite:** Spore Witch | Summoner | Spawns sproutlings, spore clouds |
| **Mini-boss:** Mother Toad | | Tongue grabs, belly-flop area attacks |
| **Warden of Roots** | Boss | Phase 1 root walls and seed bullets; phase 2 room fills with vines that shrink the arena |

### 6.2 Ember Mines (region 2)
- Palette: oranges and black rock, lava glow. Materials: Ore. Powers: Fire, Stone, Storm.

| Enemy | Archetype | Twist |
|---|---|---|
| Cinder Imp | Chaser | Explodes into burning ground on death |
| Ore Crawler | Tank | Armored front, weak back |
| Spark Wisp | Ranged | Zaps in chains between wisps |
| Kobold Bomber | Bomber | Throws timed bombs (can be knocked back) |
| Slag Brute | Tank | Leaves slowing slag |
| **Elite:** Foreman | Summoner | Calls kobold reinforcements, whip |
| **Elite:** Magma Hound | Charger | Fire trail, pack of 2 |
| **Mini-boss:** Minecart Tyrant | | Rides rails, rails change each phase |
| **Forge Warden** | Boss | Hammers the anvil to spawn weapons that attack; phase 2 floor becomes heat zones |

### 6.3 Frostpeak (region 3)
- Palette: whites, pale blues, aurora. Materials: Ore. Powers: Frost, Wind, Light.

| Enemy | Archetype | Twist |
|---|---|---|
| Snow Hare | Swarm | Very fast, hops away when hit |
| Ice Sprite | Ranged | Shots Chill you |
| Yeti Cub | Chaser | Calls a parent if left alive 20 s |
| Rime Archer | Ranged | Ice arrows freeze the floor (slippery) |
| Avalanche Beetle | Charger | Rolls into a snowball that grows |
| **Elite:** Frost Matron | Summoner | Ice mirrors that copy her attacks |
| **Elite:** Ice Knight | Tank | Shield blocks front; parry window |
| **Mini-boss:** Twin Yetis | | Two bosses, enraged when one dies |
| **Pale Warden** | Boss | Blinding light and ice pillars; phase 2 whiteout where only Radiant enemies are visible |

### 6.4 Gloam Marsh (region 4)
- Palette: purples, murky greens, fog. Materials: Wood. Powers: Shadow, Growth, Storm.

| Enemy | Archetype | Twist |
|---|---|---|
| Bog Leech | Swarm | Attaches and drains until dodged off |
| Will-o-Wisp | Ranged | Lures: invisible until close |
| Mire Hag | Summoner | Raises bog zombies |
| Croc Knight | Ambusher | Hides in water, lunges |
| Shade | Chaser | Only damageable when lit (Light helps) |
| **Elite:** Hag Mother | Summoner | Curses: swaps your power buttons for 5 s |
| **Elite:** Bog Colossus | Tank | Absorbs smaller enemies to heal |
| **Mini-boss:** The Drowned Knight | | Sword duel with parry windows |
| **Hollow Warden** | Boss | Shadow clones; phase 2 lights go out, fight by the glow of your powers |

### 6.5 The Hoard (final)
- 3 floors mixing all regions' elites, treasure everywhere that is cursed (taking it makes enemies stronger: a greed test).
- **The Hoarder (Aurel):** uses all 8 powers.
  - Phase 1: cycles two powers at a time.
  - Phase 2: uses your **kept** powers against you (mirror).
  - Phase 3: your powered villagers arrive and fight beside you with their Master abilities. The more gifts, the stronger this phase is for you.

---

## 7. Raid factions

| Faction | Unlocked after | Specialty |
|---|---|---|
| Rootbound | Run 4 | Swarms, many gates |
| Kobold Clans | Forge Warden | Bombers vs buildings |
| Frost Raiders | Pale Warden | Slow, freezing, tanky |
| Marsh Shades | Hollow Warden | Stealth, only visible in light |
| Hoard Collectors | Renown 8 | Target the most upgraded building |

---

## 8. Trinkets (run-only, 40 in full game, examples)

| Trinket | Effect |
|---|---|
| Lucky Button | +10% crit |
| Wolf Tooth | +15% damage to enemies at full HP |
| Old Kettle | Flasks heal +15% |
| Cracked Hourglass | Power cooldowns -15%, max HP -10% |
| Feather Charm | Extra dodge charge |
| Miner's Lamp | Elites drop +1 Crystal |
| Greedy Coin | +50% coins, take +10% damage |
| Seed Pouch | Heal 5 HP on room clear |

Full list is written in M8.
