# Test Ground Save Copier (ZombieBuddy) 1.0.1

1.0.1 (Test Ground 1.13.46): the mod.info description only (without this mod the picker says copying needs it, rather than "offers only a new vanilla save"). The jar is unchanged and its `TGSaveCopy.version()` still says 1.0.0.

Test Ground submod, split out of Test Ground Capture in Test Ground 1.13.44. It copies a save folder so Benchmark Save can run
on a throwaway copy. It needs ZombieBuddy (Java code, exposed to Lua as `TGSaveCopy`); Test Ground and Test Ground Capture do not need it, and Benchmark Save's
"New vanilla save" works without it.

| Lua | What it does |
|---|---|
| `TGSaveCopy.version()` | `"1.0.0"` |
| `TGSaveCopy.copyStart(mode, src, dst)` | copies `Saves/<mode>/<src>` to `Saves/<mode>/<dst>` on its own thread. Returns `""` or why not (a name that isn't a plain folder name, a mode that isn't a game mode, no such save, the copy's folder exists, a copy already running) |
| `TGSaveCopy.copyStatus()` | `idle`, `copying N of M MB`, `done` or `failed: why` |

Refused over 20 GB or without the save's size plus 512 MB free; links are left out; a failed copy removes the folder it made. Lua can't reach the game's
own copy (`IngameState.copyWorld`). Never touches the original.

Build: `GAME_CLASSES=... ZB_JAR=... java/build.sh` (reproducible; sign the jar on the PC with `zbs-sign-mod.ps1`, or allow it by hash).
