# Test Ground: Steam Workshop release

Status: **release candidate built: Test Ground 1.13.16 + Test Ground Bridge 1.1.0** (see RELEASE-CANDIDATE.md). `build.py` finds no blockers. Before uploading, replace the placeholder art and do one test run from the Workshop copy.

Run `python3 test-ground/release/build.py` after any change to the mods. It rebuilds both Workshop folders and lists anything open. It exits 1 while a blocker is open.

## Two Workshop items

| Item | Who it's for | What's in it |
|---|---|---|
| **Test Ground** | Anyone measuring their mod setup | The test bench, the fixed West Point baseline, street and tree-road data. It reads no command files and runs no code from files |
| **Test Ground Bridge** (requires Test Ground) | Modders driving runs from scripts or an AI agent | The command-file bridge (its `lua <code>` lines run only with `-debug` or the sandbox option `TestGroundBridge.AllowLua`, off by default); the Claude skill in `agent-skill/pz-test-ground/`; `tools/compare.py` |

The bridge is a separate item, not a second mod inside the Test Ground item. That way, subscribing to Test Ground never puts code-running files on anyone's disk. Raw Lua from the command file is off by default even with the bridge on: it needs `-debug` or the save's sandbox option. Its Workshop page and `mod.info` say plainly that, with that option on, any program that can write `TestGround_cmd.txt` can run Lua in the game.

## Layout (Build 42)

```
Workshop/TestGround/
  workshop.txt, preview.png
  Contents/mods/TestGround/
    common/README.txt
    42/mod.info, poster.png, icon.png
    42/media/TestGround/baseline.txt, natural.txt       the fixed test case
    42/media/lua/client/TestGround.lua
    42/media/lua/shared/TestGroundRoads.lua
Workshop/TestGroundBridge/
  workshop.txt, preview.png
  Contents/mods/TestGroundBridge/
    common/README.txt
    42/mod.info, poster.png, icon.png                    require=\TestGround
    42/media/lua/client/TestGroundBridge.lua
    agent-skill/pz-test-ground/SKILL.md, references/     the Claude skill
    tools/compare.py
```

Checked against the game's own uploader rules (`SteamWorkshopItem` in `projectzomboid.jar`, B42):
- `preview.png` must be a square 256 or 512 px PNG under 1,024,000 bytes.
- Contents can't hold `.exe`, `.dll`, `.bat`, `.app`, `.dylib`, `.sh`, `.so` or `.zip` files, and `Contents/mods` can only hold folders.
- The game loads only `common/` and version folders like `42/`. Other folders in a mod (`agent-skill/`, `tools/`) are uploaded but ignored, so the skill ships as plain files.
- Tags must come from `media/WorkshopTags.txt`. Both items use `Build 42;Misc`.

## What is in `release/`

| Path | What it is |
|---|---|
| `build.py` | Builds both items from `test-ground/TestGround` and `test-ground/TestGroundBridge` (it only reads them) and runs the checks |
| `overlay/<mod>/mod.info` | Release `mod.info`: public name and description, `poster`, `icon`, `versionMin=42.20.0`; `modversion` comes from the Lua |
| `overlay/<mod>/description.txt` | The Steam page text (BBCode). `build.py` turns it into `workshop.txt` |
| `overlay/<mod>/*.png` | Placeholder art |
| `skill/pz-test-ground/` | The Claude skill (source; copied into the bridge item) |
| `Workshop/` | The built items. They're rebuilt every time, so don't edit them by hand |

## The Claude skill

`skill/pz-test-ground/SKILL.md` teaches an agent to:
- set up and stay safe (use a bench copy of the save; only call Lua it has seen);
- use the bridge protocol and its commands;
- run the loop: status, survey, write a plan, run it, wait for `=== done`, compare;
- pick steps for a given kind of mod;
- add a test step and a survey finder to its own mod;
- read a report.

Two reference files go with it:
- `plan-format.md`: every plan key and step kind;
- `b42-lua-gotchas.md`: the Build 42 Lua lessons from the project's testing notes, with the project-specific parts left out.

The Workshop page tells players to copy the folder into `.claude/skills/` (in their project, or `~/.claude/skills/`).

## What stays out

- **Test Ground Autorun.** It quits to desktop on a flag file and depends on this PC's launcher scripts. It now requires the bridge too, so it could ship later as a third "dev" item. For now it doesn't ship.
- Mock tests, `tools/` scripts, `mocktmp`, and anything from `Zomboid\Lua\` on this PC.
- `build.py` fails the build if a shipped file contains a Windows user path, this PC's user name or the test save's name. None do.

## Still open

1. **Art.** Replace `overlay/TestGround/` and `overlay/TestGroundBridge/` `preview.png` (256x256), `poster.png` (512x512) and `icon.png` (64x64). A screenshot of the fast drive or the 500-zombie crowd would make a good preview.
2. **The fast drive removes parked cars by default** (`obstacles = clear`). In someone else's save that's surprising. Switching the shipped baseline to `obstacles = avoid` once steering has been tried in game is the fix; until then, the confirmation dialog and the description warn about it.
3. **One run from the Workshop copy.** This proves the packaged files load, not just the dev copies in `Zomboid\mods`.

## Uploading (you)

1. Run `build.py`.
2. Copy `release/Workshop/TestGround` and `release/Workshop/TestGroundBridge` into `C:\Users\tony6\Zomboid\Workshop\`.
3. Move `Zomboid\mods\TestGround` and `Zomboid\mods\TestGroundBridge` aside while testing. The game also loads mods from `Zomboid\Workshop\*\Contents\mods\`, so two copies with the same id would clash. Autorun stays in `mods`.
4. Do one baseline run in a bench save with the Workshop copies.
5. Main menu > **Workshop** > **Create and update items**. Upload **Test Ground** first, then **Test Ground Bridge**, so the bridge's page can link to it. Steam asks you to accept the Workshop agreement the first time.
6. After each upload the game writes `id=<number>` into that item's `workshop.txt`. Copy that file to `overlay/<mod>/workshop.id.txt`, so later builds update the same item.
7. On the bridge's Steam page, add Test Ground as a required item (Steam's own "Add/Remove Required Items" link; the game doesn't set it).
8. Both upload as unlisted. Check them from a clean mod list, then make them public on Steam.

## Defaults picked

- Two items, with the bridge separate.
- Visibility `unlisted` first.
- Mod ids `TestGround` and `TestGroundBridge`.
- `versionMin=42.20.0`.
- Autorun not shipped.
- The skill ships inside the bridge item, not inside Test Ground.
