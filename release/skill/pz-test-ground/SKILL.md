---
name: pz-test-ground
description: Use when measuring or testing a Project Zomboid Build 42 mod with Test Ground, driving a run through Test Ground Bridge, writing a test plan or a mod's own test step, or comparing two runs.
---

# Project Zomboid testing with Test Ground

Test Ground runs a scripted test plan in a singleplayer save and writes frame times, Lua costs and a behaviour log for each step. Test Ground Bridge lets you, the agent, drive it from outside the game: you write a command into a text file, the game runs it and appends the answer to another file. The person only has to start the game and load the test save.

More detail is in the files next to this one:
- `references/plan-format.md`: every plan key and step kind.
- `references/b42-lua-gotchas.md`: Build 42 Lua traps found in real runs. Read it before writing any Lua for the game.

## Setup (check once)
- The person needs **Test Ground** and **Test Ground Bridge** enabled in the test save's mod list. Lua Event Profiler is optional (it adds Lua cost per mod to the reports).
- The game's user folder is `%USERPROFILE%\Zomboid` on Windows and `~/Zomboid` on Linux and macOS. Under WSL that is `/mnt/c/Users/<name>/Zomboid`. Every file here is in its `Lua` folder, written `Lua/` below. Lua can only read and write files there.
- Ask for the path if you can't find the folder. Don't guess it.

## Ground rules
- **Never run in the person's real save.** A run teleports the player, spawns and removes zombies, may remove parked cars on the fast-drive road, and passes game time. Ask them to copy the save folder under `Zomboid/Saves/<mode>/` and load the copy.
- **`lua <code>` is off by default.** It runs only when the game was started with `-debug` or the save's sandbox option **Test Ground Bridge: allow lua lines** (`TestGroundBridge.AllowLua`) is on; otherwise the reply starts `refused:`. All the Test Ground commands work without it. If you need it, ask the person to turn the option on in a test save; never ask them to turn it on in a real save. Every `lua` line, run or refused, is logged to `Lua/TestGround_bridge_lua.txt`. When it is on, only call functions you have seen in the game's own Lua (`media/lua` in the install) or in the mod under test. In `-debug` mode even a caught error can stop the game in the debugger.
- **One variant per game load.** Most mods read their settings when the game loads. A before/after comparison is two loads, each with its own `label`.
- **Repeat and use medians.** Use `repeat = 3`, or three runs, and compare medians. One run is an anecdote.
- **Report what was measured.** Give the plan label, the step and the run count with every number. Say "expected" for anything you didn't measure.

## The bridge
About once a second, while the game is loaded and unpaused, the bridge reads `Lua/TestGround_cmd.txt`, empties it, runs each line and appends the results to `Lua/TestGround_out.txt`:
```
=== #12 status
idle
player 11501.5,6949.5,0 Idle
fps 60
last report TestGround_baseline_1792181710.txt
```
- Write commands by overwriting `TestGround_cmd.txt`, one per line. Read only the part of `TestGround_out.txt` after the size it had before you wrote. It only grows.
- When a run ends, `=== done <report> <trace> <perf> <spikes>` is appended.
- **No answer within about 5 s** means the game is paused, at the main menu, or the bridge isn't enabled. Many players have "pause on focus loss" on, so the game pauses as soon as they switch to another window. Ask them to keep the game in front, or to turn that option off for test runs.
- The first run in a save shows a confirmation dialog in game. The person has to click it once; until then a run reports that it was not confirmed.

| Command | What it does |
|---|---|
| `status` | Idle or running (step, pass), position, fps, last report |
| `baseline` | Runs the fixed baseline route that ships with Test Ground (West Point, vanilla map), with no survey |
| `baseline survey` / `baseline here` | Surveys the fixed start (or where the player stands), writes `TestGround_baseline.txt` and runs that |
| `survey [radius] [run] [here]` | Scans the area and writes `TestGround_site.txt` (features found) and `TestGround_survey.txt` (a plan); `run` starts that plan |
| `run [file]` | Runs a plan file from `Lua/` (default `TestGround_plan.txt`) |
| `stop` | Stops the run and writes the report so far |
| `fight` | Runs only the real-fight plan (`TestGround_fight.txt`, written with defaults if missing) |
| `treescan [N]` | A one-off job that rates the N most wooded rural roads by trees and saves the results for later surveys |
| `lua <code>` | Runs one line of Lua and prints the result (`return` is added for expressions). Only with `-debug` or the sandbox option on; otherwise `refused: ...` |

## The loop
1. `status`. This confirms the game is loaded and unpaused.
2. For a general check, `baseline` runs the standard route, the same steps on every machine. For a specific mod, find a site: `survey 40`, then read `TestGround_site.txt`. It lists walls, fences, doors (locked or barricaded), ladders, the longest street and anything a mod's finder adds, nearest first.
3. Write a plan for what you are testing (see `references/plan-format.md`) to `Lua/TestGround_<name>.txt` and send `run TestGround_<name>.txt`.
4. Wait for `=== done`. A baseline takes about 15 minutes, so check back every minute or so rather than polling fast. Then read the report and the trace.
5. Compare two runs with `python3 compare.py A.txt B.txt` (shipped next to this skill in Test Ground Bridge's `tools/` folder). It prints fps, p99, hitches and Lua ms/s per step, the mods whose cost moved most, mods that were on in only one run, and Walk To outcomes that changed.

## Choosing steps
- Chunk loading while driving: `stream 60` along a street, then `idle 30` as a baseline. `drivefast` drives a real car.
- Loot window and inventory UI: `walk 2` past containers, `turn 20` next to one, and `loot`.
- Timers that fire every 10 in-game minutes: `wait 120 3` (x20 speed). Read the hitch count and the worst frame, not the average.
- Pathfinding and movement mods: one `walkto` case per feature from the site list, with `expect` set to what the mod promises.
- Zombie AI and crowds: `fight`, `realfight`, `stress`, or `natural` for the game's own zombies.
- Anything else: add a step kind from the mod under test (below).

## Adding a test to your own mod
Keep test code in the mod under test, in a file that does nothing without Test Ground, e.g. `42/media/lua/client/<Mod>/<Mod>Test.lua`:
```lua
if not TestGround then return end

-- a step kind, used in a plan as "step = mymod_cycle 5 my_phase"
TestGround.addStep("mymod_cycle", {
    begin = function(run, step)
        step.count = step.a or 3          -- step.a, step.b: the first two numbers; step.args: every word
    end,
    tick = function(run, step, t, dtMs)   -- return true when done
        -- run.p is the player, run.plan.extra["mymod.key"] holds "mymod.key = value" plan lines
        TestGround.note("mymod", "cycle done")   -- a line in the behaviour log
        step.result = "3 cycles, all items back"   -- the one-line summary in the report
        return true
    end,
})

-- a survey finder: adds lines to TestGround_site.txt
TestGround.addFinder("mymod_spot",
    function(state, sq, x, y, z) --[[ called for each scanned square ]] end,
    function(state, cx, cy, z) return { "mymod_spot 11501,6950,0" } end)
```
- **A finder asks the mod's own placement check**, the same function the build menu calls. Never reimplement the rule. A copy drifts, and the test then passes on spots the game would refuse.
- **Build fixtures with the mod's own create functions** and the arguments the build menu passes. Don't place sprites by hand: that skips the mod's data and links, so the test passes on an object the game never makes.
- Build only when the site list has no usable spot. Check first whether the fixture is already there, so repeat runs don't stack copies, and log what you built with `TestGround.note`.
- Other functions: `TestGround.isRunning()`, `TestGround.start(plan)`.

## Reading a report
- `frames:`: fps and p50 are how it feels. p99, worst and `hitches` (100 ms+ frames) are the stutter. Patches that fix stutter show in hitches and worst, not in fps.
- `Lua in handlers` and `by mod` need Lua Event Profiler, and cover only what it wraps: event handlers, mod UI render and update, and vehicle scripts. Engine time is not in them.
- `stream`, `drive` and `treeroad` glide the player in ghost mode: chunk loading is real, but there are no vehicle physics. `drivefast` drives a real car. A result starting `FALLBACK` glided instead and says why.
- Test Ground's own handlers appear in the profiler as `TestGround`. Compare it between runs, don't subtract it.
- A `walkto` `fail` isn't a bug by itself. Compare it with the run without the mod, and with what the mod promises.
- The report header lists every active mod. Check that both runs had the mods you think they had before reading a difference.
