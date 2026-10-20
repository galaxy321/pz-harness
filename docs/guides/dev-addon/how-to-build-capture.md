# How to build your own screenshot and film capture (Java, ZombieBuddy)

*Ships with: PZ Harness Dev Add-on, opt-in "Capture" submod. Audience: modders who want to reproduce it. Draft, from Test Ground Capture 1.0.8 (about 1,500 lines of Java).*

## Why Java
The game's own screenshot copies the **front buffer** (what is on screen), so a covered or minimised window gives a blank picture. Reading the **back buffer** just before the frame is shown works for covered windows. Lua can't do that, so a small Java patch is needed. It needs ZombieBuddy (and the player must approve an unsigned jar). Keep the Lua side working without it: Test Ground falls back to the game's screenshot when the Java classes are missing.

## Mod layout
```
TestGroundCapture/42/mod.info
  require=\TestGround,ZombieBuddy
  javaJarFile=media/java/tgcapture.jar
  javaPkgName=pzmod.tgcapture
TestGroundCapture/42/media/java/tgcapture.jar     (built; the only Java file shipped)
TestGroundCapture/java/src/pzmod/tgcapture/*.java  (source, not loaded by the game)
```
Workshop uploads ban `.zip`, `.exe`, `.dll`, `.sh`, `.bat`: keep `build.sh` in the repo, not in the Workshop item (or rename).

## The three pieces
1. **A patch on the frame swap.**
```java
@Patch(className = "org.lwjglx.opengl.Display", methodName = "swapBuffers")
public static class Patch_swapBuffers {
    @Patch.OnEnter public static void enter() {
        try { Capture.beforeSwap(); } catch (Throwable e) { Capture.failed(e); }
    }
}
```
The advice body is copied into `Display`, so everything it calls must be `public`, and it must catch everything: a mistake here must never stop the game showing its frame.
2. **A Lua-facing class** marked `@Exposer.LuaClass` with `public static` methods (Lua numbers arrive as `double`). Test Ground uses `TGCapture.request(name, mode)`, `lastResult()`, `status()`, and `filmStart/Tag/Stop/Status/Take/Total/Alive/MaxMinutes/Quality`.
3. **A `main` that prints a version line** (`[TestGroundCapture] 1.0.8 loaded`) so the console shows the jar is live.

## Taking a still
In `beforeSwap`, when a request is pending: read the pixels of the back buffer (`glReadPixels`), flip them (GL is bottom-up), hand them to a **background thread** that writes the PNG into `Zomboid\Screenshots`. Never encode on the render thread. A minimised window has no frame to read: skip the shot and say so in the report. Optional `world` mode reads the game's offscreen world buffer instead (no UI) and works while minimised only if the game keeps drawing.

## Filming (the part that took iterations)
- Read frames through **three pixel-buffer objects in turn**: start the read for this frame, map and copy the one from two frames ago. That avoids stalling the GPU.
- Copy into a **pool of arrays**; queue them to **2 writer threads** that scale and write JPEGs (quality 0.85). If the queue is full, **drop the frame and count it**; never wait on the render thread.
- Write `frames.txt` (`<seq> <epoch ms> <tag> <file>`) in order; take files from it, not by counting.
- **Stop safely:** `filmStop()` from Lua must only set a flag and return (waiting on the game thread froze the game ~1 s). The render thread flushes at its next frame; a watchdog ends the film after 2 s with no render frame.
- **Self-stop** so a crashed run can't fill the disk: no heartbeat from Lua for 10 s, game left the world, film length cap (20 min default), under 2 GB free disk.
- Return every pooled array exactly once (an early version returned it twice on a failed write).

## Build
`javac --release 21 -cp "$GAME_CLASSES:$ZB_JAR"` over the sources; `GAME_CLASSES` is `projectzomboid.jar` (B42 ships Java 25 class files, so use a JDK 25+ javac or a copy with lowered class versions for compile only), `ZB_JAR` is ZombieBuddy's jar. Fixed file times make the jar reproducible. Sign it per ZombieBuddy's instructions on your PC.

## Check it
Console shows the `java active` line; `TGCapture.status()` from a plan or the bridge; take a still with the window covered and check it isn't black; run a 30 s film and compare the frames written with `frames.txt`.

Not verified: the code fragments are copied from the real source; the build wasn't re-run for this guide.
