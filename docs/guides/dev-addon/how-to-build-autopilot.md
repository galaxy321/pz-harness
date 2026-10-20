# How to build your own autopilot (hands-free runs)

*Ships with: PZ Harness Dev Add-on. Audience: people who want unattended runs without installing Autorun. Draft, from Test Ground Autorun 1.5.x.*

An autopilot is a small mod that, from the **main menu**, loads a save, runs a test plan, writes a result file and quits. It does nothing unless a flag file tells it to.

## Contract (what an outside runner sees)
- Flag in: `Zomboid\Lua\TestGround_autorun.txt` (`key = value` lines, `#` comments). With no file, or no `save`, the mod does nothing.
- Result out: `Zomboid\Lua\TestGround_autorun_done.txt` (`result = done | stopped: <why> | timeout | no run | load failed`, then the report file names). The game quits to desktop 5 s later.
- Keys that matter: `save`, `mode`, `plan`, `delay`, `timeout`, `quit`, `skip`, `start`, `loads`, `addmods`, `origin`, `endscreen`. See the Autorun guide for meanings.

## Build it in this order
1. **Run at the menu.** Only mods in the main-menu mod list run there (`Zomboid\mods\default.txt`). `OnTick` doesn't fire at the menu; count time on `OnFETick`.
2. **Load the save** a few seconds after the menu shows, with vanilla `MainScreen.continueLatestSave(mode, saveName)` (what Load > Play does).
3. **Survive the Lua reload.** The game reloads Lua with the save's mods while loading, so the menu code runs again. Write a small state file ("already asked for a load", with a time) and skip a second load while it is recent (Autorun uses 3 minutes).
4. **Act only in the right save.** In game, compare the loaded save's name with `save`; if different, do nothing. Then **empty the flag file** so one flag means one run.
5. **Unpause.** A loaded save sits paused and `OnTick` stops: use `OnRenderTick` to set speed 1 (`UIManager.getSpeedControls():SetCurrentGameSpeed(1)`) after ~5 s, and keep that watchdog for the whole job (players with "pause on focus loss" stall otherwise).
6. **Wait `delay`** in game seconds (not counting paused time), then start the plan through the test mod (`TestGround.start(plan)` or `TestGround.command("run " .. plan)`).
7. **Time out.** If the run doesn't finish within `timeout`, stop it and write `result = timeout`.
8. **Finish:** write the done file, wait 5 s, quit with `getCore():quitToDesktop()` (or `getCore():quit()` to the menu for repeated loads).
9. **Don't stall on prompts.** Missing-mod and world-conversion pop-ups need a click Lua can't give; the outside runner must time out and kill the game.

## The outside half
Lua can't press the loading screen's "click to start". This project uses pzopt's harness (`pzopt-harness.txt` with `mode=play`). Any equivalent (a keypress sent to the window) works. The runner also copies a clean bench save into place first, writes the flag, launches the game, waits for the done file with a timeout, then kills the game if needed. That runner is the auto-queue (see `guides/auto-queue.md`).

## Test it
Mock a fake menu and game under lupa (flag missing, empty, wrong save, single load across a reload, delay with pauses, done file, timeout, quit): the project's mock does this in 20 checks. Then run once in game with a short plan.

Not verified: written from the Autorun source header and notes; not rebuilt from this guide.
