# Test Ground UI checks: design (2026-10-19)

Goal: every UI build clears its layout checks in one PC job, with no human in the loop, so the user's own look finds nothing the harness could have caught. Applies to Test Ground (end screen, run banner, confirm dialog) and Autorun (Benchmark Save button, the save picker and its "copying" state). Base versions: Test Ground 1.13.29, Autorun 1.5.8. Build 1 shipped as Test Ground 1.13.30 + Autorun 1.5.9.

## 1. In-game self-check (`TestGroundUICheck.lua`)

One file in TestGroundAutorun (it loads at the main menu and in game; Test Ground calls it when present). It runs on a live window, using the real `getTextManager()`, and needs no per-window code for most checks:

- **Text drawn in `render()`.** For one frame (the probe frame) the check wraps the window instance's `drawText`, `drawTextCentre` and `drawTextRight`, records each call (text, x, y, font), then measures it with `MeasureStringX` and `getFontHeight`.
- **Child controls.** It walks `getChildren()`. For an `ISButton` it measures the title in the button's font. For an `ISScrollingListBox` it measures each item's text and the row height. For any element it reads its rectangle.
- **Banner.** The banner is drawn straight through the text manager, so it is checked by calling `K.bannerText` and measuring the two lines against the screen width.

Defects, each with a code and the element's name (`window/element`), and the numbers that broke it:

| Code | Rule (margins in px) | Tonight's bug it would have caught |
|---|---|---|
| `TEXT_WIDE` | label width + 2x8 padding > control width, or text x + width > parent width - 8 | button label wider than its button; end-screen line past the panel |
| `ROW_SHORT` | list row height < font height + 4, or two text lines closer than the font height | picker rows shorter than the font |
| `OUTSIDE` | child rectangle not inside its parent's (footer, buttons) | footer past the window edge |
| `OFF_SCREEN` | window not fully inside the screen | |
| `OVERLAP` | two sibling controls, or two drawn texts, intersect | |
| `RENDER_ERROR` | `render()`/`prerender()` raised during the probe frame (error text kept) | API absent in this build |
| `API_MISSING` | a game call the UI code uses is nil in this build (each window lists the calls it needs, e.g. `MeasureStringX`, `getFontHeight`, `quitToDesktop`) | API absent in this build |
| `TIGHT` (warning) | under 10% spare width or height. A larger in-game font size would break it | |

Output: one console line per defect, `[TestGround] UICHECK DEFECT end_screen/stats_line TEXT_WIDE 642 px in 580 px`, plus one summary line per window. The same lines go to `Zomboid/Lua/TestGround_uicheck.txt`, and the run report gets a `ui check:` line (windows checked, defects, warnings). Windows also check themselves the first time they open in normal use, and log only. Nothing is shown to the player.

**Fonts for the mocks.** The check also writes `TestGround_fontmetrics.txt`: the width of every printable character and the line height for Small, Medium and Large at the user's settings. The mock tests load it in place of their fixed 7 px guess, so most overflow is caught in the cloud before a build is queued at all.

## 2. Harness step: the UI tour

An Autorun flag line `uitour = 1` (Bridge can't do this: it only polls in game, and the picker lives at the main menu). One PC job runs it:

1. **Main menu.** Check and capture the Benchmark Save button. Open the picker with fixture rows added: a 200-character name, a multi-byte name, 30 rows so the list scrolls, every mode/mark tail. Check it, capture it, then set the "Copying the save..." note and the disabled-button state, check and capture again, and close.
2. **Load the test save** (existing Autorun path). A few seconds before the start, check and capture Autorun's own "Waiting for the world to settle" banner (added in 1.5.8). Then show the confirm dialog: check, capture, and close it without an answer.
3. **Banner.** Draw it with a fake run state for settle, gap and step, each with the longest real step name and pass numbers. Check and capture each.
4. **End screen.** Open it with fixture summaries: 14+ rows with long and skipped names, a stopped run, countdown running, countdown paused, and no countdown. Check, capture and close each one (Keep playing, never Close game).
5. **Finish.** Write `TestGround_uitour.txt` (the manifest) and quit.

Each state takes about 2 frames to open, then the self-check, then one `TGCapture.request(name, "back")`, waiting until `busy()` is false. Shot names are `TG_ui_<build>_<screen>_<state>.png` in Zomboid/Screenshots. The manifest has one block per shot: file name, screen size, the window's and each element's rectangle, and that state's defects. If Capture is missing or fails at the menu, the shot is marked `NO SHOT` and the PC thread takes it with Steam F12 at the same point. Desktop capture is never used.

**Resolution (user, 2026-10-19):** shots and checks follow the game's own resolution setting. The tour reads `getCore():getScreenWidth()/getScreenHeight()` when it starts, writes them at the top of the manifest, and every check and the PC verdict use those numbers. Nothing assumes 2560x1440, and the tour never changes the game's display options.

Prediction for the PC brief: about 5 minutes (1 minute at the menu, 2 to 3 minutes loading, 1 minute in game). Expected: 12 shots (button 1, picker 2, settle banner 1, confirm 1, run banner 3, end screen 4), each the size the manifest records (2560x1440 on the user's current setting), and 0 defects on the cleared screens.

## 3. What the PC thread compares against (no human)

A cloud script, `test-ground/tools/uishots.py`, run on the staged shots and the manifest, gives one verdict per shot: `layout ok: picker/long_names`, or `DEFECT picker/long_names ...`.

**Where it runs (after the first PC tour, 19 Oct):** the PC has no Python, so nothing here runs on the PC. The PC thread stages the manifest, the check file, the font metrics and the shots, and then runs these in its own cloud container (or hands them to this thread): `python3 -I tools/uishots.py TestGround_uitour.txt <shots> --expect 2560x1440` and `python3 -I ui_mock_test.py TestGround_fontmetrics.txt`. `--expect` is the game's resolution setting. A tour that ran at another size, as the first one did at 2133x1200 while the monitor was asleep, fails every shot and is run again; fonts change with the resolution, so its metrics are not kept.

1. **Self-check lines.** Any `DEFECT` fails the shot, and the verdict quotes the line.
2. **Pixel checks** (independent of Lua's own measuring). The shot exists and matches the manifest's screen size (the game's resolution setting). The window's area is not blank or black. No text-coloured pixels sit in the 6 px band just outside each panel's and button's rectangle. This catches anything the probe frame missed, such as text drawn by a child or another mod.
3. **Golden diff.** Each screen is compared with the last shot the user approved, stored in `test-ground/ui-golden/<screen>_<state>.png`. Any change outside the elements the build's brief says it changed is flagged with its rectangle.
4. **Vision check.** The PC thread looks at each crop against a one-line expected layout per state, kept in the manifest (for example: "three buttons in one row at the bottom, every label whole, title top left"). It reports only what doesn't match.

The PC thread's result note leads with its mismatches against the prediction, then one line per shot. This replaces the user's first look.

## 4. What still needs a human eye

- **Whether it reads well.** Wording, colour, contrast and emphasis are judgment calls, not geometry.
- **Interaction.** Hover and click feel, dragging the window, focus with a controller, and the countdown really closing the game. The tour clicks only the safe buttons.
- **Their own data and setup.** Their real saves, other mods' windows over ours, and in-game font sizes other than theirs (the `TIGHT` warnings point at the likely breaks).
- **The goldens.** The user approves each new golden once. After that, a diff that isn't explained by the build is the only thing that comes back to them.

## Effort and first build

About **2 builds, plus 1 fix round** after the first PC tour.

- **Build 1** (Autorun 1.5.8 + Test Ground 1.13.29, one review). It contains: `TestGroundUICheck.lua` with all codes in the table; the font-metrics dump; the `uitour = 1` path covering every screen above; the manifest; and the `ui check:` report line. Mock tests replay tonight's five bugs from the old versions' layouts and must flag each one. The cloud tool `uishots.py` (no game build) ships with it.
- **Build 2** (Test Ground 1.13.32 + Autorun 1.5.11) fixes what the first PC tour found: the confirm dialog ran off the screen (now wrapped and centred on the game's own size), a picker row with Chinese characters was cut (the font has no glyph, the game draws "?" but measures 0 px; widths now count it, and a GLYPH_MISSING warning names it), the list's real clip edge, text drawn in prerender, Character Info closed before the banner shots, `--expect` in uishots. It also carries the reviewer's six minors.
- **Build 3** adds a `uicheck open` command that runs the same check on every open top-level window, including other mods' windows and Crane Test Ground's. It also adds the golden store. There is no extra pass at another resolution: the tour always uses the game's own setting.
