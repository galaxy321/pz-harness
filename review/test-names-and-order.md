# Test Ground baseline: step names and order (review, 18 Oct)

Read from the 1.13.6 working copy (`test-ground/TestGround/`, baseline.txt already says `glide_fog`), the step code in `Tests/*.lua`, and the step tables from allon-1017-1854 and the sievedev series of 16 Oct. Nothing in Test Ground was changed; the Mod test ground thread owns those files.

## What each step really does

| # | Name now | Step line | Mechanism (from the code) | Name right? |
|---|---|---|---|---|
| 1 | drive | `drive 60 20` | Ghost-mode **glide** at 20 tiles/s, south from the start for 30 s and back (`Drive.lua:9`, no vehicle) | No: glide, not drive |
| 2 | walk | `walk 2` | Vanilla Walk To round the 4 route points, 2 laps | Yes |
| 3 | fight_small | `fight 6 30` | 6 zombies come at you in god mode; the script puts the nearest down, you don't swing | Yes |
| 4 | loot | `loot` | Walk to 6 containers, loot window fills, items out and back | Yes |
| 5 | fight_large | `fight 40 60` | Same as fight_small with 40 zombies | Yes |
| 6 | drive_back | `drive 40 20 -1` | The same **glide**, but **north** from the start (the opposite direction), 20 s out and back | No: a glide, and "back" reads as returning along step 1's road |
| 7 | drive_trees | `treeroad 40 20` | Teleport to Tioga Road, **glide** back and forth in ghost mode | No: glide, not drive |
| 8 | drive_fast | `drivefast 241 120` | A real car on Dixie Highway with cruise control at 120 km/h | Yes |
| 9 | corpse_lay | `corpses 30` | Glide along Dixie Highway laying ~13,000 corpses (30 per chunk). Test Ground's own work: 32 to 46 fps, 16 to 37 hitches in every run | Name fine, but it's setup, not play |
| 10 | drive_corpses | `drivefast 45 120` | Real car through the chunks that now hold corpses | Yes |
| 11 | corpse_clear | `corpses clear` | Glide the stretch again, take every corpse off | Name fine, but it's clean-up, not play |
| 12 | fight_real | `realfight 6 30 ... weapon=Base.BaseballBat` | You swing the bat yourself through the attack input, can't-die mode | Mostly. "real" is vague next to fight_small; the mechanism is that you swing |
| 13 | stress_500 | `stress 500 60` | 500 zombies crowd you in ghost mode, then every zombie and body within 45 tiles is removed | Yes |
| 14 | (fog) | `weather fog` | Takes no time; its phase name is the weather word | n/a |
| 15 | glide_fog | `drive 40 20` | Glide **south** 20 s out and back, in fog | Yes now, but see the twin problem below |
| 16 | (clear) | `weather clear` | Takes no time | n/a |

## Problems with the order

1. **The fog glide has no clear twin.** glide_fog is `drive 40 20` (south, 40 s); the clear glide south is `drive 60 20` (60 s) and the 40 s glide is the north one. Neither clear step covers the same tiles for the same time, so "fog costs frames" can't be read straight off the table. In the four runs above glide_fog came out at 87.6, 86.5, 115.6 and 116.8 fps against step 1's 91.6, 78.4, 120.3 and 122.6, which doesn't separate fog from route length.
2. **The first measured step doubles as warm-up.** Step 1 starts after a 10 s settle. Whether that hurts is unclear from the data (step 1 was the lowest glide in the machinery run and the highest in the others), so this is cheap insurance, not a proven effect.
3. **Setup and clean-up steps sit among the play steps.** corpse_lay and corpse_clear are the slowest rows in every table, yet measure Test Ground laying and lifting corpses, not the game being played. Nothing aggregates across steps today, but any total or "worst step" a reader takes from the table picks them up.
4. **Like steps are scattered.** The three glides are at 1, 6 and 15, the four fights at 3, 5, 12 and 13, and loot sits between two fights, so it walks among fight_small's bodies.
5. **The fight_real row is mislabelled in the step tables.** step-table.txt (allon and sievedev) shows step 12 as `weapon=Base.BaseballBat`, because whatever builds that table takes the last word of the step line. Test Ground's own phase is correct (`mark start ... s12 fight_real`). Putting the name last in the plan line fixes the table without touching that script. `weapon=` is read from anywhere in the line (`K.stepOpts`, `Melee.lua:278`), so this is safe.

## Proposed baseline

```
settle = 30                                   # was 10

step = walk 2 walk
step = loot loot
step = drive 60 20 glide_south
step = drive 40 20 -1 glide_north
step = weather fog
step = drive 60 20 glide_fog                  # was 40 s: now the exact twin of glide_south
step = weather clear
step = treeroad 40 20 glide_trees
step = drivefast 241 120 drive_fast
step = corpses 30 setup_corpses
step = drivefast 45 120 drive_corpses
step = corpses clear cleanup_corpses
step = fight 6 30 fight_small
step = fight 40 60 fight_large
step = realfight 6 30 weapon=Base.BaseballBat fight_swing
step = stress 500 60 stress_500
```

The run gets 40 s longer (settle +20 s, glide_fog +20 s).

## One line per change

- **drive → glide_south**: it's a ghost glide, and the baseline's drive direction is fixed south (`drive = 0.000,1.000`).
- **drive_back → glide_north**: same glide, opposite direction; "back" suggested a return trip along step 1's road.
- **drive_trees → glide_trees**: treeroad glides in ghost mode, no car.
- **glide_fog 40 s → 60 s**: the same tiles and time as glide_south, so the fog cost is the difference between two rows.
- **glide_fog right after glide_north**: in the glide group and close to its twin; glide_north sits between them so glide_fog isn't loading chunks glide_south has only just left.
- **corpse_lay → setup_corpses, corpse_clear → cleanup_corpses**: a `setup_` and `cleanup_` prefix lets any reader or script drop those rows from play metrics by name. If you'd rather keep your own words, `corpse_lay` and `corpse_clear` can stay and be listed as excluded instead.
- **fight_real → fight_swing** (optional): says what differs from fight_small, which is that you swing yourself.
- **name after weapon=**: fixes the `weapon=Base.BaseballBat` row in the step tables.
- **settle 10 → 30**: unmeasured time for the first-run costs before the first row.
- **Order by kind: on foot, glides, car, fights, stress last**: like steps sit together; walk and loot run before any fight leaves bodies at the start; the chunk-streaming steps the load mods target run while the game is freshest; stress_500, the heaviest step, goes last and its clean-up removes every body round the start.

Unchanged: walk, loot, drive_fast, drive_corpses, fight_small, fight_large, stress_500. The other plans (drive, driveview, gear, natural) already name what they do.

## What applying it touches

- **Old runs stop matching.** compare.py keys each step by its whole step line (`STEP` regex, `compare.py:15`), so any rename or argument change means 1.13.6 runs don't line up with older ones. Either rerun the vanilla and all-on references once on 1.13.6 as the new series, or give compare.py an old-to-new name map.
- **Saved skip flags.** Autorun flags such as `skip = fight_small,fight_large` keep working; any that name drive_back, drive_trees, corpse_lay or corpse_clear need the new names.
- **The survey writes the same list** (`Survey.lua:710-730`), and mock_test.py checks it at lines 785, 822, 838 and 841.
- **Optional, code side:** step kinds `drive` and `treeroad` are in the `drive` group in `K.GROUPS` (`Core.lua:750`), next to the real car, though they glide. So `skip = drive` drops the glides along with drive_fast, and the banner shows "glide_south (drive)". Moving them to the existing `glide` group (and, if wanted, accepting `glide` as a kind alias for `drive`) would make the group match too. This changes what `skip = drive` means.
- **drive_corpses against drive_fast**: a 45 s step against a 241 s one. For the corpse cost, compare drive_corpses with drive_fast's first 45 s from the per-second perf CSV, not with the whole-step row.
