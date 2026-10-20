---
name: pz-run-benchmark
description: Use when a Project Zomboid player wants to benchmark their mod list with PZ Harness (Test Ground): run the standard test in a throwaway copy of a save, then read the result and say what is slow.
---

# Run and read a benchmark

Draft, ships with the PZ Harness core item. Needs no Bridge. For comparing two runs in depth, see `pz-read-test-report`.

## Run it
1. **Never in the real save.** Use the **Benchmark Save** button in the main menu (pending in 1.13.20; it runs on a throwaway copy), or copy the save folder under `Zomboid\Saves\<mode>\` yourself and load the copy.
2. Enable PZ Harness (Test Ground) in the copy's mod list. Optional: Lua Event Profiler for per-mod Lua cost.
3. Keep the game in front and unpaused. Right-click > Test Ground > **Go to West Point, survey and run baseline**, and confirm the first-run dialog (it removes parked cars on the fast-drive road).
4. Wait for the end. Expect about 15 to 20 minutes. The report is in `Zomboid\Lua\TestGround_baseline_<id>.txt`.

## Read it
- Per step, not overall: `fps` and `p50` are how it feels; `p99`, `worst` and `hitches` (frames over 100 ms) are the stutter.
- Setup steps (`corpse_lay`, `corpse_clear`) measure Test Ground itself: ignore them.
- Rough guide: a step well below your other steps of the same kind (a drive far under another drive) is where to look; `Lua by mod` (with the profiler) names the mods.
- One run is an anecdote. For a claim ("this mod costs X"), run twice more with and without it, and compare medians.

## Answer in this shape
"Slowest step: <name> at <fps> fps (p99 <ms>, <n> hitches). Top Lua cost: <mod> <ms/s>. Based on <n> run(s)." Then one suggested next test. End with `Not verified: ...` (or `Not verified: nothing`).
