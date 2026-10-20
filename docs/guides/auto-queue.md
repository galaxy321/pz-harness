# Auto-queue: running benchmarks back to back (PowerShell)

*Ships with: PZ Harness Dev Add-on as **instructions only**. The scripts live in the user's public Test Ground GitHub repo (**URL pending: repo not created yet**). Copies for review: `test-ground/auto-queue/` (unchanged from the PC, 20 Oct). Draft. I read the scripts; I did not run them.*

Auto-queue is the outside half of the autopilot (see `dev-addon/how-to-build-autopilot.md`). It runs on your PC, outside the game, so it is not in the Workshop item. **Read a script before you run it.** None of these files contain credentials; the queue page listens on localhost only, with no authentication.

## The pieces
| Script | What it does |
|---|---|
| `tg-job.ps1` | **One job.** Writes the Autorun flag file, starts a hidden `pz-mute.ps1`, launches the game, polls every 5 s for the done file (counted only if it has a `result =` line), optionally refuses a run whose window is narrower than `-MinWidth` (reads `Initial resolution` from `console.txt`), gives the game `-CloseWaitS` seconds to quit, kills it if still up, then copies the done file, `console.txt` and every `TestGround_*` file newer than the start into `perf-logs\<Name>\` and logs to `run.log` and `queue-notes.txt`. Refuses to start if the game is already running. Parameters: `-Name`, `-Flag` (flag lines), `-TimeoutMin` (30), `-MinWidth`, `-CloseWaitS` (40). |
| `reset-perftest-save.ps1` | Deletes and recreates `<Source> - PerfTest` from the source save so every run starts byte-identical, then edits the copy's `mods.txt`: adds the Test Ground mods and a profiler (`-Profiler none\|v1\|v2`), `-ExtraMods`, `-RemoveMods`, `-ModsFile`, `-NoSaveMods`. Only ever deletes the PerfTest copy; refuses to run while the game is open. |
| `pz-mute.ps1` | Mutes only the game's own Windows audio sessions while a job runs, unmutes when the flag file appears. |
| `run-chain33.ps1`, `run-chain34.ps1` | **Example chains:** install the build under test, rebuild the save, run `tg-job` (twice, with a wait if the game is open), restore the normal mods and the empty flag file, label runs that came up below the wanted resolution. Copy one and edit it; they are specific to this PC's backups folder layout. |
| `queue-server.ps1` + `queue-page.html` | A live page at `http://localhost:8000/` (polls `/state` every 5 s): whether the game is running, the newest run's log, the notes, `pc-queue.md`, and an estimated finish time from `queue-plan.json` (list of `{name, match, minutes}`). A file called `HOLD` in the logs folder shows as a hold. |
| `encode-frames.ps1` | Turns Capture's film frames (`frames.txt` + JPEGs) into one clip per step, each under a size cap (default 18 MB), using the frame timestamps for real timing. Needs `ffmpeg`. |

## What you must change before using them
Hard-coded in the scripts, so replace with your own:
- `C:\Users\tony6\Zomboid` (user folder): `tg-job.ps1`, both chains, `reset-perftest-save.ps1`, `queue-server.ps1`.
- The Steam game path `C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid`: `tg-job.ps1`.
- The save name `Lumberjack - Copy` (default `-Source`, also in the chains' flag lines).
- An ffmpeg path under `perf-logs\tools\ffmpeg\...`: `run-chain34.ps1`.
- The folder layout under `perf-logs\` (`mod-backups\`, `benchmark-check\`, `showcase\`, `tools\`): created by hand on the original PC; make your own or edit the chains.
(In the repo these should become parameters or one config block at the top; that is a clean-up for whoever publishes them.)

## The job contract (what to rely on if you write your own)
1. Never run in the real save: rebuild a throwaway copy first.
2. Write the harness file your "click to start" presser needs, and the flag file (`save`, `mode`, `plan`, `delay`, `timeout`, `quit`, plus `endscreen = 1` if you want the end screen in an unattended run).
3. Launch muted; wait for a done file with `result =`; give the game time to quit; kill if needed.
4. Collect the report, trace, perf, spikes, done file and `console.txt` into a per-run folder.
5. Restore your normal mods, `default.txt` and an empty flag file, whatever happened.
6. **Before each run, state the expected duration and one expected number; after it, end the note with `Not verified: ...`.**

Not verified: nothing was run; the table is from reading the scripts.
