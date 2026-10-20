package pzmod.tgmemory;

import oshi.hardware.GlobalMemory;
import oshi.software.os.OSProcess;

// Samples memory on its own daemon thread. Process and system RAM come from OSHI (shipped in the
// game jar; the game itself uses SystemInfoFFM), the Java heap from Runtime, and VRAM from a
// query queued on the render thread (NVX_gpu_memory_info on NVIDIA, ATI_meminfo on AMD; other
// GPUs have none). Any failure turns just that part off for the session and is logged once.
final class Sampler {
    static final long SAMPLE_MS = Long.getLong("tgmemory.ms", 500L);
    static final double MB = 1024.0 * 1024.0;

    static volatile double processMB = -1, processPeakMB = -1, processVirtualMB = -1;
    static volatile double heapUsedMB = -1, heapPeakMB = -1, heapCommittedMB = -1, heapMaxMB = -1;
    static volatile double systemTotalMB = -1, systemFreeMB = -1, systemFreeLowMB = -1;
    static volatile double vramTotalMB = -1, vramFreeMB = -1, vramFreeLowMB = -1;
    static volatile String vramSource = "pending";
    static volatile double samples = 0;
    static volatile String oshiError = null;

    private static Thread thread;
    private static OSProcess proc;
    private static GlobalMemory mem;
    private static boolean oshiTried;
    private static volatile boolean vramQueued;
    private static volatile boolean resetPeaks;

    static synchronized void start() {
        if (thread != null) return;
        thread = new Thread(Sampler::loop, "TGMemory sampler");
        thread.setDaemon(true);
        thread.setPriority(Thread.MIN_PRIORITY);
        thread.start();
        System.out.println("[TestGroundMemory] java active (" + TGMemory.VERSION + "), sampling every " + SAMPLE_MS + " ms");
    }

    static void mark() { resetPeaks = true; }

    static String status() {
        return "TestGroundMemory " + TGMemory.VERSION + ": " + (long) samples + " samples, process RAM "
                + (oshiError == null ? "on" : "off (" + oshiError + ")") + ", VRAM " + vramSource;
    }

    private static void loop() {
        while (true) {
            try {
                sample();
            } catch (Throwable t) {
                System.out.println("[TestGroundMemory] sample failed: " + t);
            }
            try {
                Thread.sleep(SAMPLE_MS);
            } catch (InterruptedException e) {
                return;
            }
        }
    }

    private static double low(double cur, double v, boolean reset) {
        if (v < 0) return cur;
        return (reset || cur < 0 || v < cur) ? v : cur;
    }

    private static double high(double cur, double v, boolean reset) {
        if (v < 0) return cur;
        return (reset || v > cur) ? v : cur;
    }

    static void sample() {
        boolean reset = resetPeaks;
        resetPeaks = false;
        Runtime rt = Runtime.getRuntime();
        long total = rt.totalMemory();
        double used = (total - rt.freeMemory()) / MB;
        heapUsedMB = used;
        heapCommittedMB = total / MB;
        heapMaxMB = rt.maxMemory() == Long.MAX_VALUE ? -1 : rt.maxMemory() / MB;
        heapPeakMB = high(heapPeakMB, used, reset);
        sampleOshi(reset);
        sampleVram(reset);
        samples = samples + 1;
    }

    private static void sampleOshi(boolean reset) {
        if (oshiError != null) return;
        try {
            if (!oshiTried) {
                oshiTried = true;
                try {
                    oshi.SystemInfoFFM ffm = new oshi.SystemInfoFFM();
                    proc = ffm.getOperatingSystem().getCurrentProcess();
                    mem = ffm.getHardware().getMemory();
                } catch (Throwable ffmFail) {
                    System.out.println("[TestGroundMemory] OSHI FFM failed (" + ffmFail + "), trying OSHI JNA");
                    oshi.SystemInfo jna = new oshi.SystemInfo();
                    proc = jna.getOperatingSystem().getCurrentProcess();
                    mem = jna.getHardware().getMemory();
                }
            } else if (proc != null) {
                proc.updateAttributes();
            }
            if (proc != null) {
                double rss = proc.getResidentSetSize() / MB;
                processMB = rss;
                processVirtualMB = proc.getVirtualSize() / MB;
                processPeakMB = high(processPeakMB, rss, reset);
            }
            if (mem != null) {
                systemTotalMB = mem.getTotal() / MB;
                double free = mem.getAvailable() / MB;
                systemFreeMB = free;
                systemFreeLowMB = low(systemFreeLowMB, free, reset);
            }
        } catch (Throwable t) {
            oshiError = t.getClass().getSimpleName() + ": " + t.getMessage();
            processMB = -1;
            System.out.println("[TestGroundMemory] process RAM off: " + oshiError);
        }
    }

    private static void sampleVram(boolean reset) {
        if (vramQueued) return;
        String src = vramSource;
        if (!src.equals("pending") && !src.startsWith("nvx") && !src.startsWith("ati")) return;
        final boolean r = reset;
        vramQueued = true;
        try {
            zombie.core.opengl.RenderThread.queueInvokeOnRenderContext(() -> {
                try {
                    Vram.query(r);
                } catch (Throwable t) {
                    vramSource = "off (" + t.getClass().getSimpleName() + ")";
                    System.out.println("[TestGroundMemory] VRAM off: " + t);
                } finally {
                    vramQueued = false;
                }
            });
        } catch (Throwable t) {
            vramQueued = false;
            vramSource = "off (" + t.getClass().getSimpleName() + ")";
            System.out.println("[TestGroundMemory] VRAM off: " + t);
        }
    }

    static void setVram(String src, double totalMB, double freeMB, boolean reset) {
        vramSource = src;
        vramTotalMB = totalMB;
        vramFreeMB = freeMB;
        vramFreeLowMB = low(vramFreeLowMB, freeMB, reset);
    }
}
