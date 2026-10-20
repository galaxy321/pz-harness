import pzmod.tgmemory.TGMemory;
// Runs the sampler outside the game: OSHI and heap numbers must be real, VRAM must stand down cleanly.
public class Smoke {
    public static void main(String[] a) throws Exception {
        TGMemory.mark();
        byte[][] hog = new byte[64][];
        for (int i = 0; i < 64; i++) { hog[i] = new byte[1 << 20]; java.util.Arrays.fill(hog[i], (byte) 1); }
        Thread.sleep(1600);
        System.out.println(TGMemory.status());
        System.out.printf("process %.0f MB (peak %.0f), heap %.0f MB (peak %.0f, max %.0f), system free %.0f of %.0f MB, vram %s %.0f%n",
            TGMemory.processMB(), TGMemory.processPeakMB(), TGMemory.heapUsedMB(), TGMemory.heapPeakMB(), TGMemory.heapMaxMB(),
            TGMemory.systemFreeMB(), TGMemory.systemTotalMB(), TGMemory.vramSource(), TGMemory.vramFreeMB());
        boolean ok = TGMemory.processMB() > 50 && TGMemory.heapPeakMB() >= 64 && TGMemory.systemTotalMB() > 100 && TGMemory.samples() >= 3 && hog[63][0] == 1;
        System.out.println(ok ? "SMOKE OK" : "SMOKE FAILED");
        System.exit(ok ? 0 : 1);
    }
}
