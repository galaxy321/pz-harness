# Release candidate (updated 20 Oct 2026)

**Test Ground 1.13.43** (cleared Change review as the Steam candidate), **Autorun 1.5.22**, **Bridge 1.1.0**, **Capture 1.0.8**, **Memory 1.0.0**. Built into `Workshop/PZHarness` and `Workshop/PZHarnessDevAddon`; transport zip `workshop-1.13.43.zip`. Replaces the 18 Oct 1.13.16 candidate.

## Must do before upload
- PC run confirming Test Ground works alone (queued by the coordinator: quick test, UI tour, flag-file run).
- The user clicks **Benchmark Save** on the release build and watches the end screen.
- Art: art-v2 wired in (variant A main, pending the user's word); `workshop-1.13.43-art.zip` carries it. Upload the gallery how-to image on the Steam page by hand.
- Create the Steam items; after the first upload copy each `workshop.id.txt` back.

## Open
- **Memory jar:** the packaged `tgmemory.jar` is the one reviewed on 18 Oct (confirmed by Change review, 20 Oct); keep Memory in.
- **Capture placement:** built into PZ Harness because Benchmark Save needs it to copy a save; the user was asked on a decision card (`TG_CAPTURE_IN` flips it).
- **Flag-file engine now ships in the core** (`TestGroundAutorun.lua`, inert without `Zomboid\Lua\TestGround_autorun.txt`; can load a named save, add mods to its list, make a new save, quit to desktop; runs no Lua from the file). Disclosed on the PZ Harness page. This differs from the 16 Oct rule that the core reads no command files.
- Update both items together (Autorun 1.5.22 needs Test Ground 1.13.43; older Autorun duplicates two file names).
- The test save's name appears in a comment in the core's `TestGroundAutorun.lua` and in UI-tour test data; scrub in a later build.
- Core README doesn't yet mention Benchmark Save, the Capture requirement or the flag-file engine (asked of the Mod test ground thread); the Steam text does.
- `shooting` and `aimsweep` research plans ship in the core; the page says they aren't part of the normal tests.
- Fast drive still removes parked cars on the road (Benchmark Save runs in a copy; the page says so).
- Open review Minors from 18 Oct (trace write every 10 s, stale done_loadN files, build cheat or gun mouse not restored if stopped mid-step), unless fixed since.
- ZombieBuddy needs its own installer; the page links its Workshop item (3619862853).
- Bridge skill updated for quick baseline, step kinds and durations; `skill` still names Bridge-era behaviour for the confirm dialog (see docs/notes/existing-bridge-skill-review.md items 3 and 6).

## Left out on purpose
Auto-queue (GitHub), autopilot and Autorun-hands-free guides, `pz-autorun-benchmark` skill, mock tests, Crane Test Ground.

## Preview video (recorded 2026-10-21 03:14Z)
- YouTube (user upload of showcase/showcase-film-v2.mp4): https://youtu.be/WZlsqgk8dAQ
- To add on the PZ Harness Workshop page: Add/edit images and videos, paste the link (after upload).
- Main preview art: variant A, final (user yes, 2026-10-21).

## Published (unlisted) 2026-10-20 23:22 local, ids recorded 2026-10-21 03:25Z
- PZ Harness: id=3823830771 https://steamcommunity.com/sharedfiles/filedetails/?id=3823830771
- PZ Harness Dev Add-on: id=3823830939 https://steamcommunity.com/sharedfiles/filedetails/?id=3823830939
- Uploaded package: workshop-1.13.43-art.zip (50e56e4d...). Ids saved in overlay/items/*/workshop.id.txt; next build.py run keeps them. Part B (hand check of Benchmark Save) not done; items stay unlisted.
- Pending: gallery image + required-item link on add-on page + YouTube link (user, by hand); 1.13.44 split (Save copier mod / Capture to add-on).
