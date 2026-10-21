# PZ Harness: Steam Workshop release

Two Workshop items, each holding several mods (a player ticks the opt-in ones in the game's mod list). Built by `build.py` from the cleared build. Current candidate: **Test Ground 1.13.43 / Autorun 1.5.22 / Bridge 1.1.0 / Capture 1.0.8 / Memory 1.0.0** (see RELEASE-CANDIDATE.md).

```
TG_SHIP=/path/to/unzipped/ship-1.13.43 python3 test-ground/release/build.py
```
`TG_SHIP` is the unzipped ship zip (it holds TestGround, TestGroundAutorun, TestGroundCapture); Bridge and Memory are read from `test-ground/`. `TG_SRC_<id>` overrides one mod's folder; `TG_CAPTURE_IN=PZHarnessDevAddon` moves Capture to the add-on. Exits 1 while a blocker is open.

| Item (Workshop title) | Mods inside | For |
|---|---|---|
| **PZ Harness** | `TestGround` (core, shown as "PZ Harness"), `TestGroundCapture` (opt-in, Java, ZombieBuddy; copies saves for Benchmark Save), `TestGroundMemory` (opt-in, Java, ZombieBuddy) | Anyone measuring their mod setup |
| **PZ Harness Dev Add-on** | `TestGroundBridge` (command-file bridge; `lua` lines off by default), `TestGroundAutorun` (UI check and tour) | Modders driving runs from scripts or an AI agent |

Mod ids are unchanged (`TestGround`, `TestGroundBridge`...); only display names and Workshop titles are renamed.

## Layout (Build 42)
```
Workshop/<item>/workshop.txt, preview.png
  Contents/mods/<id>/common/, 42/mod.info, poster.png, icon.png, 42/media/...
  PZHarness: TestGround/{agent-skill/(pz-run-benchmark, pz-read-test-report, pz-mod-test-step), guides/quick-start.md, tools/compare.py}
  DevAddon:  TestGroundBridge/{agent-skill/(pz-test-ground, pz-mod-writing, pz-mod-performance), guides/(how-to-build-*), tools/compare.py}
```
`mod.info` comes from the source (id, version, require, java*) with name, description and versionMin from `overlay/mods/<id>/info.txt`. The Steam pages are `overlay/items/<item>/description.txt`; art is `overlay/mods/<id>/` (poster 512, icon 64) and `overlay/items/<item>/preview.png` (256). Art is from `art-v2/` (variant A as main preview, pending the user's word); the Steam gallery how-to image is `overlay/items/PZHarness/gallery/howto-benchmark-save-1920.png` (added by hand on the Steam page, not part of the upload folder).

Checked against the game's own uploader rules (B42): preview.png square 256 or 512 and under 1,024,000 bytes; no .exe .dll .bat .app .dylib .sh .so .zip; only folders in Contents/mods; tags from the game's list. Other folders in a mod (`agent-skill/`, `guides/`, `tools/`) are uploaded but ignored by the game. `build.py` also blocks Windows user paths, the PC user name, unfilled `@REPO_URL@`, and checks the core has no Lua-from-file, a multiplayer guard, a confirm dialog, the quick plan and Benchmark Save.

## What stays out
Auto-queue scripts (PowerShell; in the GitHub repo https://github.com/galaxy321/pz-harness, linked from both pages), the autopilot and Autorun-hands-free guides (name this PC), the `pz-autorun-benchmark` skill, mock tests, `ship-*` zips, Crane Test Ground.

## Uploading (needs the PC)
1. Unzip `workshop-1.13.43.zip` (transport only; never upload it) into `C:\Users\tony6\Zomboid\Workshop\` so `PZHarness\` and `PZHarnessDevAddon\` sit there. Move `Zomboid\mods\TestGround`, `TestGroundBridge`, `TestGroundAutorun`, `TestGroundCapture`, `TestGroundMemory` aside: the game also loads `Workshop\*\Contents\mods\`, so same ids clash.
2. In a bench save: Benchmark Save > Quick test; then the full test. Check the end screen by hand.
3. Main menu > Workshop > Create and update items: upload **PZ Harness** first, then the **Dev Add-on**. Both upload unlisted.
4. The game writes `id=<number>` into each `workshop.txt`; copy it to `overlay/items/<item>/workshop.id.txt` so later builds update the same item.
5. On the Dev Add-on's Steam page add PZ Harness as a required item; on PZ Harness add ZombieBuddy (3619862853) as a note or required item.
6. Check from a clean mod list, then make both public.
