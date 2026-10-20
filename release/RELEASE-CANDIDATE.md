# Release candidate, 18 Oct 2026

**Test Ground 1.13.16** + **Test Ground Bridge 1.1.0**, built into `Workshop/` by `build.py` (source: `ship-1.13.16.zip`, sha256 `54796372...c59f`; set `TG_SRC_TestGround` to build from an unzipped ship folder).

Why 1.13.16 and not 1.13.18/19: it cleared review and ran on the PC (camera check and showcase). 1.13.18 cleared review but its drive run is still queued; 1.13.19 is still in review. Both only add driving fixes, a pop-up closer and a look-around test.

Left out: Autorun, Capture (Java), Crane Test Ground, ship-zip dev files, mock tests.
Not in 1.13.16 (arrive with a later version): drive iteration 3-4 fixes, pop-up closer, mod:look.

Still open before upload: placeholder art; one run from the Workshop copies; fast drive still removes parked cars (obstacles = clear; disclosed in the confirm dialog and description); open review Minors (heartbeat trace write every 10 s, stale done_loadN files, build cheat/gun mouse not restored if stopped mid-step).
Bridge 1.1.0 has no Bridge-specific review in the 18 Oct gate (only the 17 Oct "acceptable").

## Must-do before upload (added 18 Oct, 21:13)
- **The user clicks the Benchmark Save button themselves on the release build and watches the end screen.** The button is the whole experience for people who only download the mod, so it is checked by hand, not only by a scripted run.
- **1.13.22 (real test names, end screen, Benchmark Save) is now the likely release build** once its in-game check passes. It supersedes 1.13.16: repackage with `TG_SRC_TestGround=<unzipped ship>/TestGround python3 build.py`, rebuild `workshop-<version>.zip`, update this file and README, and rerun the Workshop-copy check.

## Workshop-copy run (release-check-1722, 21 min, reported 18 Oct 23:56)
Result: all 16 baseline steps have frame stats, run ended "result: done", 0 ERROR/STACK TRACE lines from Test Ground or Bridge (the 552 hits were WARN "spawn zombie" lines), no refused or missing-file lines. Dev copies restored. Report: perf-logs\release-check-1722\TestGround_baseline_1792359454.txt.
Gap: neither console nor report names Bridge 1.1.0 or the path the files loaded from, so the run does not prove the Workshop copies were the ones loaded.
Decision: add one line each to the report header, "Test Ground Bridge <version>" (or "not installed") and the mod's load path, in the Test Ground thread's next build. Worth it: otherwise a user can't tell which copy a report came from. Recheck on the release build.
