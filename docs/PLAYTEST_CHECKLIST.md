# Owner playtest checklist (M0 to M5)

Everything built so far, in play order. Tick a box when it works; add a note under any item that does not.
Report back by ID ("A1 ok, C2 bug: ..."), screenshots welcome.

## A. Title screen

- [x] **A1.** Title shows Level, XP, coins banked, Runs; buttons: Go to the village, New game, Controls (plus 3 test rooms).
- [x] **A2.** **Playtest log** toggles on/off and stays that way after restarting the game.
- [x] **A3.** **Open log folder** opens a folder.
- [x] **A4.** **Controls:** rebind one key and one gamepad button, back out, check the village hint bar shows them, then Reset to defaults.

## B. New game and the first gift

- [x] **B1.** **New game** starts over (Runs 0, Level 1).
- [x] **B2.** Village has Tilly (Farmer), Maren (Guard), Brann (Smith) and empty plots. Osk (Healer) is not there yet.
- [x] **B3.** Gate caption and villager hints are readable near the bottom; nothing hides under the sign.
- [x] **B4.** Talk to each villager: their line shows, then goes back to "Welcome home" when you walk away.
- [x] **B5.** Brann's forge opens and closes.
- [x] **B6.** Notice board shows Renown and who moves in next.
- [x] **B7.** Tab / Map opens the character sheet; it closes.
- [x] **B8.** In the village, dodging never runs out and there is no stamina bar.

## C. First run: movement and combat feel

- [x] **C1.** Stamina bar, HP, flasks and power slots show.
- [ ] **C2.** Moving, attacking while moving, the 3-hit combo and turning mid-combo feel responsive (nothing sticky).
- [x] **C3.** Dodge through enemies; stamina runs out and refills.
- [x] **C4.** Flask heals; a hit while drinking cancels it and keeps the charge.
- [ ] **C5.** Aiming with mouse and with right stick; aim assist helps with the stick.
- [x] **C6.** Enemies: Tusk Boar (charges, stunned by walls), Seedling / Sproutling (split), Thorn Archer (arrows leave thorns when they miss).
- [ ] **C7.** Hit-stop and screen shake feel good, not too much.

## D. Run structure

- [x] **D1.** Doors show the next room's type letter; Tab shows the map.
- [x] **D2.** Rooms seen: Fight, Elite (Elder Boar or Spore Witch), Merchant, Event, Rest, Treasure.
- [ ] **D3.** Loot pops out, drifts to you, flies to you after a room clears.
- [x] **D4.** Merchant: flask, heal, Power Shard; wares you cannot use are greyed out.
- [ ] **D5.** Events (Mossy Shrine, Wishing Well): HP costs never kill; the last choice is always free.
- [ ] **D6.** Mini-boss **Mother Toad:** tongue pulls you in, belly flop lands where you stood, enrages at half HP.
- [ ] **D7.** Region boss **Warden of Roots:** seed volleys, root walls, slam if you stand next to it.
- [ ] **D8.** Save and quit mid-run (Esc) shows **Continue run** on the title; the gate says "continue your run" and resumes it.
- [ ] **D9.** A full run takes about 12 to 15 minutes. Your time: ____

## E. Results and death

- [x] **E1.** Results show XP, coins, materials, mastery and the training tick preview.
- [x] **E2.** Spend attribute points and Power Shards on the results screen.
- [ ] **E3.** Die on purpose: "You fell", half the loot kept, the run still counts.

## F. Powers

- [ ] **F1.** The boss drops power orbs; you pick one and it waits at the Shrine.
- [ ] **F2.** Try each power: Fire (projectile), Frost (shards), Growth (healing patch), Stone (shield that bursts).
- [ ] **F3.** Q / E / R (or LB / RB / Y) cast; the HUD shows cooldowns.
- [ ] **F4.** Level 3 and level 5 upgrades feel different (Tuning room "Power level" to check fast).

## G. The Choice (the heart of the game)

- [ ] **G1.** New game: the Shrine glows, the Elder says your first Spark must be given.
- [ ] **G2.** First gift: you cannot keep it; it goes to the villager the Elder suggests.
- [ ] **G3.** Gift ceremony plays; the villager changes color, gets a sash and the power icon; their house gets trimmed.
- [ ] **G4.** Later Choices: Keep (slot 1 to 3), Merge (same power levels up), Give to a villager, Let a kept power go, Leave it behind.
- [ ] **G5.** With 3 slots full, you are forced into a real decision.
- [ ] **G6.** Grow stronger at the Shrine spends points and shards.
- [ ] **G7.** Feel: did you hesitate on at least one Choice? Why?

## H. Villager services

- [ ] **H1.** Tilly with a power: extra flasks in runs.
- [ ] **H2.** Brann with a power: sells an infusion (once).
- [ ] **H3.** Maren with a power: nothing in runs until Master (raids are not built yet). Does that feel like a wasted gift?

## I. Training and Renown

- [ ] **I1.** After each run, "Novice 1/3, 2/3..." goes up.
- [ ] **I2.** After 3 runs: Adept moment (camera, star, pennant on the roof).
- [ ] **I3.** Renown (top right) rises with gifts; at Renown 2, Osk moves in with a moment.
- [ ] **I4.** After 7 runs: Master moment (gold crown, second pennant), then the lesson teaches you a Technique.
- [ ] **I5.** Character sheet lists the Technique and who taught it.
- [ ] **I6.** The Technique works in a run (for example Regrowth, Ember Step, Cold Temper).
- [ ] **I7.** With Osk and a revive token, you get back up at 30% HP.

## J. Debug console (editor only, F5)

- [ ] **J1.** ` or F2 opens it in the village.
- [ ] **J2.** `give_power fire` puts a power at the Shrine.
- [ ] **J3.** `set_tp farmer 7` (after gifting Tilly) triggers Master and the lesson.
- [ ] **J4.** `add_renown 10` triggers Renown moments.
- [ ] **J5.** In a run: `skip_room` and `god_mode`.

## K. Playtest build and logs

- [ ] **K1.** A log file appears in the log folder after a session, with your Choices in it.
- [ ] **K2.** GitHub > Actions > **Playtest builds** > Run workflow; download the Windows zip.
- [ ] **K3.** The zip runs on Windows (More info > Run anyway); test rooms and debug tools are hidden.
- [ ] **K4.** `docs/PLAYTEST.md` (in the zip) is clear for someone new.

## L. Overall feel (short answers are fine)

- [ ] **L1.** Did you want "one more run"?
- [ ] **L2.** Did any gift feel like a loss, or like an investment?
- [ ] **L3.** Was a Master's lesson exciting?
- [ ] **L4.** Anything confusing, boring or too hard?
