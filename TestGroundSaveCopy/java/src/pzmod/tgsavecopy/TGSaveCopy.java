package pzmod.tgsavecopy;

import me.zed_0xff.zombie_buddy.Exposer;

// Lua side (global TGSaveCopy). Test Ground's Benchmark Save button copies a save so the run happens on a throwaway copy.
//   copyStart(mode, src, dst) -> "" when a copy of Saves/<mode>/<src> to Saves/<mode>/<dst> has started on its own
//                                thread, else why not (not a plain folder name, not a game mode, no such save, the
//                                copy's folder exists, a copy is already running)
//   copyStatus()              -> idle, "copying N of M MB", done, or "failed: why"
// Refused over 20 GB or without the save's size plus 512 MB free; links are left out; a failed copy removes the
// folder it made; the original is never touched. Lua can't reach the game's own copy (IngameState.copyWorld).
// 1.0.0 (Test Ground 1.13.44): this is Test Ground Capture 1.0.7's copySaveStart/copySaveStatus, unchanged, in a mod
// of its own so a release can ship the copy without the screenshot and film code.
@Exposer.LuaClass
public class TGSaveCopy {
    public static final String VERSION = "1.0.0";

    public static String version() { return VERSION; }
    public static String copyStart(String mode, String src, String dst) {
        try {
            return SaveCopy.start(java.nio.file.Paths.get(zombie.ZomboidFileSystem.instance.getSaveDir()), mode, src, dst);
        } catch (Throwable t) {
            return "copy failed: " + t;
        }
    }
    public static String copyStatus() { return SaveCopy.status(); }
}
