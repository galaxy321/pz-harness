# PZ Harness (Test Ground)

Dev tools for Project Zomboid (Build 42) that run a fixed test plan in a singleplayer save, so a mod or patch can be measured and checked the same way every time.

Current shipped versions: Test Ground 1.13.46, Test Ground Autorun 1.5.24, Test Ground Capture 1.0.9, Test Ground Save Copier 1.0.1, Test Ground Bridge 1.1.0, Crane Test Ground 0.2.1.

## Layout

| Folder | What it is |
|---|---|
| `TestGround/` | The main mod: test plans, steps, runner, report and end screen. Start with `TestGround/README` material in `docs/guides/quick-start.md`. |
| `TestGroundAutorun/` | UI check and UI tour. Since 1.13.43 the hands-free autorun engine and Benchmark Save live in `TestGround/` itself. |
| `TestGroundSaveCopy/` | Save Copier: copies a save for Benchmark Save. Ships in the PZ Harness item. |
| `TestGroundCapture/` | In-game screenshots, film and save copies. Lua plus a Java part (`java/`, needs ZombieBuddy and the game classes; `build.sh` documents the paths). The prebuilt `tgcapture.jar` is included. |
| `TestGroundBridge/` | Lets a script send commands to a running game. |
| `TestGroundMemory/`, `DriveRecorder/` | Smaller helper mods (memory sampling, drive recording). |
| `crane-test-ground/` | Crane Test Ground: `mod/` is the game mod, `test/` its mock tests. |
| `release/` | Steam Workshop packaging: `build.py` (rebuilds the Workshop layout from the mod trees), `overlay/` (Workshop text), `art-v2/`, `RELEASE-CANDIDATE.md`. `RELEASE-CANDIDATE.md` describes an older candidate (1.13.16) and is being rewritten. |
| `docs/` | Guides, skills and `INDEX.md` (start there). |
| `auto-queue/` | PowerShell scripts that queue and run test jobs on a Windows PC. Not part of the Steam package. |
| `tools/`, `ui-golden/` | Build helpers, review notes and reference material. |
| `mock_test.py`, `autorun_mock_test.py`, `ui_mock_test.py`, `compare.py` | Mock tests that run the Lua with `lupa` (`python3 -I mock_test.py`; they expect `TestGround/42/...` next to them). |

Each mod folder follows the game layout: `42/` for Build 42 files and `common/`.

## Hard-coded paths

The `auto-queue/` scripts contain paths like `C:\Users\tony6\Zomboid\perf-logs`. They were written for one PC and are left as is. Search and replace `C:\Users\tony6` with your own user folder before using them.

## Not included

Credentials, Steam IDs and the ZombieBuddy signing material are not in this repository. Signed jars must be signed on your own machine.
