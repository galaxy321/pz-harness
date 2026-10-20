# What the user's own Dixie Highway drive says about Test Ground's driving

For the Mod test ground thread's steering rework in `TestGround/Tests/Drive.lua` (1.13.x). Written 17 Oct from the
user's manual drive of 16 Oct, 20:05 to 20:15 PC time (`perf/jfr/manual-drive-1016-2004/`), compared with the
algorithm's latest Dixie run (`perf-logs/tg11210-fixedbaseline-0456`, Test Ground 1.12.10, step `drive_fast`).
Nothing here has been run in game yet; each proposal has a test.

## Where the human data comes from

The manual drive has no car telemetry: no position, speed, steering or health log (Test Ground had no
recorder in manual mode). But the JFR recording logs every save-file read, and on the way back each chunk
the car passes is read from `Saves\...\map\<cx>\<cy>.bin`. The leading edge of those reads moves with the car
(load radius 9 chunks, 1 chunk = 8 tiles), so it gives the car's position and speed second by second for the
**return leg only, 20:10:46 to 20:13:30**. On the outbound leg the chunks were new and came from the map
packs, which leave no file reads.

- Per-second table: [return-leg-per-second.csv](return-leg-per-second.csv) (speed is the edge's movement over 3 s).
- How reliable it is: the speed scale is exact (8 tiles per chunk row). The road column it gives, x of about
  11640, and the westward row, y of about 8765, are the same squares the algorithm drove, which is a good
  check. Edge timing is good to about 1 s: the edge stopped within a second of the traffic light hit that
  the FPS thread found in the JFR at 20:11:47.3. Positions are good to about ±1 chunk.
- Speeds are in tiles/s; km/h means tiles/s × 3.6, the same convention as the `steer` trace lines (the
  dashboard read 120 when that came to 121).

## The human, section by section (return leg, heading east, then north to West Point)

| PC time | Where (tiles) | What | Speed |
|---|---|---|---|
| 20:10:46–56 | y≈8765, x 11370→11520 | eastbound | ~15 t/s (54 km/h) |
| 20:10:56–11:13 | x 11520→11600, y≈8765 | **wreck jam 2**, the algorithm removed 11 vehicles at x 11520–11580 here | **4.7 t/s**, about 2 s stopped |
| 20:11:14 | x≈11640 | turns north | |
| 20:11:14–35 | y 8744→8576 | **wreck jam 1**, the algorithm removed 20+ at y 8638–8695 | **8 t/s (29 km/h)**, never stops |
| 20:11:35–46 | y 8576→8300 | speeding up out of the jam | 21→26 t/s |
| 20:11:47 | y≈8300 | **hits a traffic light** | stopped about 3 s |
| 20:11:50–55 | | back on the road | average 14 t/s, about 25 t/s 6–7 s after the hit |
| 20:11:55–12:34 | y 8240→7225 | the long straight | **25.8 t/s (93 km/h), steady** |
| 20:12:34–39 | y≈7180 | bend from north to east | ~20 t/s (inferred: both axes moving) |
| 20:12:39–53 | x 11700→12090 | straight | 25.7 t/s |
| 20:12:53–13:04 | x≈12100, y≈7180 | junction into West Point | slow or stopped for 7–10 s |
| 20:13:04–26 | y 7140→6750 | town street | 18.9 t/s (68 km/h) |

About 2,700 tiles in 160 s (17 t/s on average) with one collision, through both wreck jams, and no restarts.

## The algorithm on the same road (1.12.10, drive_fast, 239 s)

- **Clean straight (leg 1): better than the human.** 1,365 tiles in 51 s, holding 33–34 t/s (120 km/h)
  within 0.1 tile of the centre. Steering on a straight is not the problem.
- **The wreck jams (legs 2–3, s 1386–1686, the same two jams):** 300 tiles in 37 s. The human took the
  same 37 s or so, but the algorithm needed 2 fresh cars, 3 legs cut short for drifting 6.5 tiles off
  centre, 5 knocks and 2 spins (gain halved twice), and removed 41 "late-loaded" vehicles that appeared
  only 34–44 tiles ahead. At 33 t/s that is 1.0–1.3 s of warning; at the human's 5–8 t/s it is 5–8 s.
- **Whole run:** 2,868 tiles in 239 s (12 t/s), 8 fresh cars (each one a teleport of 3 to 120 tiles), 14
  knocks, 4 spins, and 2 corners taken as a full stop and a turn on the spot. The stuck spots on legs 4–10
  (bushes and trees west of x 11163, on a street 14 tiles wide with its centre −4 to +5.7 tiles off the
  map's line) are west of anywhere the human was recorded, so there's no human data for them.
- **Getting going:** 0 to 20 t/s took 12 s on leg 1, with a dip from 12.5 to 9.9 t/s while the torque
  steering corrected an 11° heading error at 24 km/h. The human was back to about 24 t/s 6–7 s after
  stopping at the traffic light.

## Proposed changes, most evidence first

### 1. Crawl through wreck jams instead of driving them at cruise (strong evidence)
The human slowed to 5–8 t/s for both jams and threaded them without stopping. The algorithm went in at
cruise, and everything that went wrong on legs 2–3 came from wrecks it saw too late.
- **Change:** in the `leg` phase, count vehicles found by `clearAhead`, `recheckAhead` or `dodge` (removed
  or not, late-loaded included) within the next 60 tiles. With 2 or more, or 1 within 30 tiles, cap cruise at
  `K.JAM_KMH = 25` (7 t/s) and brake to it like for a bend (`need` = v² − vb² over 2·FAST_DECEL, + 8). Hold the
  cap until 20 tiles past the last vehicle seen, then go back to cruise. Use the jam cap in both `clear` and
  `avoid` modes, since late-loaded wrecks appear about 40 tiles ahead either way.
- **Test:** `drive_fast` on Dixie Highway, the stretch from s 1380 to 1700. Pass: 0 fresh cars, at most 1
  knock, 0 legs cut short there, and no slower than now (37 s or less). The rest of the run must not lose
  time: count tiles in the first 60 s against 1.12.10's leg 1.

### 2. Get going again after a knock before reaching for a fresh car (good evidence, one event)
After hitting the traffic light at about 25 t/s, the human was stopped about 3 s and at cruise again within
about 8 s, with no restart. The algorithm's answer to stuck or drifting is a teleported fresh car (8 per
run), which skips road and hides the stretch that caused it.
- **Change:** on `stuck` or `recentre`, first try twice on the same car: brake to a stop, back up 2 s if
  Lua can drive reverse (check: a negative regulator or the controller's reverse; if it can't, skip the
  back-up), line up with `fastAlign`, and start the leg again. A fresh car only after the second failure
  in the same 30 tiles. Report "recovered in place" separately from "fresh cars".
- **Test:** `drive_fast` and `drive_corpses`. Pass: fresh cars per `drive_fast` down from 8 to 2 or fewer,
  and the share of the 239 s spent in a car (not respawning or gliding) goes up.

### 3. Don't steer hard at a crawl, and get to speed faster (moderate evidence)
The human reached about 24 t/s 6–7 s after a stop. The algorithm took 12 s to reach 20 t/s, and lost speed
at 24 km/h to an 11° correction.
- **Change:** scale the wanted turn rate by `min(1, tps / 12)` below 12 t/s, and require the heading to be
  within 3° before the leg starts (FAST_ALIGN_TOL is 2°, but leg 1 started 11° off after the creep). Leave the
  cruise at the set speed from the start, with no ramp.
- **Test:** the time from the start of each leg to 25 t/s. Pass: median 8 s or less (now 12 s or more).

### 4. Slow for bends instead of stopping (weak evidence, inferred)
The human took the north-to-east bend at y≈7180 at about 20 t/s, roughly 78% of straight speed. They
crawled or stopped only at the junction into West Point. The algorithm stops completely for any path
corner of 40° or more, and turns on the spot.
- **Change:** split corners at 70°. From 40° to 70°, drive through at `K.FAST_CORNER_ROLL_KMH = 45`, braking
  like for a bend, with the pursuit look-ahead at `FAST_PURSUIT_MIN`. Keep stop-and-turn for 70° and up, or
  where `streetCentre` sees a junction (a row much wider than the street).
- **Test:** the corners on legs 6 and 9 of the 1.12.10 road. Pass: no stuck and no leg cut short within 30
  tiles after a corner, and less time per corner than now (braking at 639 s to the next leg at 652 s, about 12 s).
- Caveat: we know the human's speed through the bend, not its angle, so check the path's angle there
  before tuning.

### 5. A run at the human's pace, alongside the 120 km/h run (measurement, not steering)
The user's real driving runs at about 26 t/s on straights and 19 t/s in town. The test drives at 33 t/s,
which streams about 27% more chunks per second, so its fps numbers are harsher than what the user sees.
- **Change:** a plan option `drivefast 120 93` (cruise at 93 km/h), or a `drive_human` test line, next to
  `drive_fast`, so the report has a number for both.
- **Test:** none beyond the report showing both rows.

## What this drive couldn't tell us, and how to get it next time

Braking distances, how hard and how often the user steers, where in the lane they drive, and the whole
outbound leg aren't in this recording. For a proper comparison, give Test Ground a **record mode** for
manual drives. Every 250 ms, write the car's x, y, heading, `getCurrentSpeedKmHour`, the regulator and
brake state, the driver's health, vehicles within 40 tiles, and any knock (heading rate over 45°/s). Then
have `manual-drive.ps1` turn it on. One more drive on the same road then gives real braking and steering
numbers for proposals 1 to 4. The chunk-read trick above also works for any run with a JFR recording, but
only on chunks the save has already written.
