package pzmod.tgcapture;

/**
 * 1.0.8: the aim point, for Test Ground's Shooting step. The game aims a ranged weapon at the real mouse
 * (AimingReticle.getXA/getYA, which return Mouse.getXA/getYA for keyboard-and-mouse play), and Lua's setMouseXY
 * does not move that: GLFW ignores glfwSetCursorPos while the window is not focused, so the cursor stays where it
 * was and the character never turns to the zombie. While Lua has set a point here, the two patched methods
 * (Patches.Patch_aimX/aimY) return it instead. The advice bodies are copied into AimingReticle, so everything
 * they call is public and they catch everything.
 *
 * The point goes stale after TTL_MS: a run that stops without calling aimClear leaves the mouse alone again.
 */
public class Aim {
    public static final long TTL_MS = 500;
    public static volatile boolean on;
    public static volatile int player;
    public static volatile int x;
    public static volatile int y;
    public static volatile long setAtNs;
    public static volatile long used;      // times the game asked for the aim X and got ours
    public static volatile long sets;      // times Lua set a point

    public static boolean active(int idx) {
        return on && idx == player && (System.nanoTime() - setAtNs) < TTL_MS * 1000000L;
    }

    public static void set(int idx, int px, int py) {
        player = idx;
        x = px;
        y = py;
        setAtNs = System.nanoTime();
        on = true;
        sets++;
    }

    public static void clear() { on = false; }

    /** The game's AimingReticle.getXA(idx) result, or the point Lua set. */
    public static int ax(int ret, int idx) {
        try {
            if (active(idx)) { used++; return x; }
        } catch (Throwable t) { /* the game's own value */ }
        return ret;
    }

    public static int ay(int ret, int idx) {
        try {
            if (active(idx)) return y;
        } catch (Throwable t) { /* the game's own value */ }
        return ret;
    }

    public static String status() {
        return "aim override " + (on ? "on" : "off") + ", " + sets + " points set, the game took the X " + used + " times"
            + (on ? ", point " + x + "," + y + " for player " + player : "");
    }
}
