package pzmod.tgmemory;

import me.zed_0xff.zombie_buddy.Exposer;

// Lua side (global TGMemory): version(), status(), mark(), and the getters below, all in MB
// (-1 when unknown). A daemon thread samples every SAMPLE_MS; the getters only read its
// volatile fields, so Lua never waits on OSHI or the render thread. Peaks are since mark().
@Exposer.LuaClass
public class TGMemory {
    public static final String VERSION = "1.0.0";

    public static String version() { return VERSION; }
    public static String status() { Sampler.start(); return Sampler.status(); }
    public static void mark() { Sampler.start(); Sampler.mark(); }

    public static double processMB() { Sampler.start(); return Sampler.processMB; }
    public static double processPeakMB() { return Sampler.processPeakMB; }
    public static double processVirtualMB() { return Sampler.processVirtualMB; }
    public static double heapUsedMB() { Sampler.start(); return Sampler.heapUsedMB; }
    public static double heapPeakMB() { return Sampler.heapPeakMB; }
    public static double heapCommittedMB() { return Sampler.heapCommittedMB; }
    public static double heapMaxMB() { return Sampler.heapMaxMB; }
    public static double systemTotalMB() { return Sampler.systemTotalMB; }
    public static double systemFreeMB() { return Sampler.systemFreeMB; }
    public static double systemFreeLowMB() { return Sampler.systemFreeLowMB; }
    public static double vramTotalMB() { return Sampler.vramTotalMB; }
    public static double vramFreeMB() { return Sampler.vramFreeMB; }
    public static double vramFreeLowMB() { return Sampler.vramFreeLowMB; }
    public static String vramSource() { return Sampler.vramSource; }
    public static double samples() { return Sampler.samples; }
}
