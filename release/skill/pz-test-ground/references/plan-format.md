# Test Ground plan format

A plan is a text file in `Zomboid/Lua/`. Each line is `key = value`; `#` starts a comment. Points are `x,y,z` in world tiles (z defaults to 0). Right-click in game > **Test Ground** records start, route, road and Walk To lines into `TestGround_plan.txt` from where the player stands.

## Run settings
| Key | Meaning |
|---|---|
| `label` | Names the report files. Change it per variant (`sieve-on`, `sieve-off`) |
| `settle` | Seconds to wait after setting the scene, before measuring (10) |
| `repeat` | Run the step list this many times (1; use 3 for medians) |
| `return` | 1 = put the player back where they were at the end |
| `autostart`, `autostart_delay` | 1 = start this plan N seconds after the save loads |
| `measure` | 0 = run the steps without frame statistics |
| `skip` | Comma list of phase tags or step kinds to leave out; the report marks each "skipped by flag" |

## Scene
| Key | Meaning |
|---|---|
| `start` | `westpoint` (the fixed start on the vanilla map: South St, West Point, 11501,6949,0), `here`, or `x,y,z` |
| `time` | Hour of day (`12`), or `keep` |
| `weather` | `clear`, `rain`, `fog` or `keep` |
| `zombies` | `none` (removed now and every 2 s, except during fights), `keep`, or a number to spawn round the start |
| `god` | 1 = god mode during the run. Outside `-debug` the game refuses, and fights use "can't die" mode instead |
| `gamespeed` | 1 to 3 for the whole run |
| `weapon` | Item type to hold in `realfight` |
| `crowd` | How many zombies may attack at once in `realfight` (2) |
| `obstacles` | `clear` (default: remove cars and wrecks ahead of the fast drive) or `avoid` (steer round them) |

## Places the steps use
| Key | Used by |
|---|---|
| `route = x,y,z` (several) | `walk`: the loop of points |
| `road = x,y` (several) | `stream`: driven back and forth |
| `drive = dx,dy` | `drive`: the direction, e.g. `0,1` |
| `loot = x,y,z` (several) | `loot`: container squares |
| `treeroad = x,y,z` (two) | `treeroad`: the two ends |
| `fastroad = x,y,z` (several), `fastname`, `fastwidth` | `drivefast`: the street's centre line, name and width |
| `zone = x,y,z` | `natural`: the centre of the zombie zone |
| `walkto = name \| sx,sy,sz \| tx,ty,tz \| expect [\| via]` | `walkto`: `expect` is `arrive`, `fail` or `any`; `via` is `vanilla` or `walktoplus` |
| `<mod>.<key> = value` | A mod's own step: `run.plan.extra["<mod>.<key>"]`, a list of strings |

## Steps
`step = <kind> <numbers> [tag]`. Steps run in order. A word after the numbers is the phase tag: it goes in the per-second file and to the profiler's `mark()`.

| Step | What it does |
|---|---|
| `idle S` | Stands still for S seconds |
| `turn S` | Turns on the spot every half second |
| `walk N` | Walks the `route` N times with vanilla Walk To (real pathfinding) |
| `stream S [tiles/s]` | Glides along the `road` points at driving speed (15) in ghost mode |
| `drive S [tiles/s] [-1]` | Glides out along `drive` for half of S and back (20 tiles/s); `-1` reverses the direction |
| `treeroad S [tiles/s]` | Back and forth along the `treeroad` points |
| `drivefast S [kmh]` | A real car along `fastroad` on cruise control, braking for corners and turning back at the end |
| `wait S [speed]` | Stands still at game speed 1, 2 or 3 (x1, x5, x20) |
| `walkto` | Every `walkto` case: teleport to its start, walk to its target, record the outcome and the states seen |
| `loot` | Walks to each `loot` container, lets the loot window fill it, moves up to 3 items out and back |
| `fight N S` | N zombies in a ring come at the player; put down one at a time; leftovers removed after S seconds |
| `realfight N S` | N zombies, and the player swings through the attack input. Nothing is put down by script |
| `stress N S [D]` | N zombies spawned D to D+15 tiles out (20), 25 a tick, lured for S seconds, then everything within 45 tiles removed |
| `natural S [stand\|run] [R]` | The game's own zombies at `zone`: a noise every 4 s draws them; stand, or run a ring of radius R (25) |
| `weather W` | Sets `clear`, `rain`, `fog` or `keep` for the steps after it; takes no time |

## Example: before/after for a loot-window patch
```
label = uithrottle-on
settle = 10
repeat = 3
start = westpoint
time = 12
weather = clear
zombies = none
god = 1

step = idle 30 idle
step = walk 2 walk
step = turn 20 turn
step = loot loot

route = 11481,6929,0
route = 11521,6929,0
route = 11521,6969,0
route = 11481,6969,0
loot = 11501,6963,0
loot = 11502,6963,0
```
Run it once with the patch on and once with it off (label `uithrottle-off`), each in a fresh load of the same save copy, then `python3 compare.py` the two reports.
