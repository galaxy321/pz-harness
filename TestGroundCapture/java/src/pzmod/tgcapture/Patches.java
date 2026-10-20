package pzmod.tgcapture;

import me.zed_0xff.zombie_buddy.Patch;

// The advice body is copied into Display, so what it calls must be public, and it catches
// everything so a mistake here can't stop the game's frame from being shown.
public class Patches {
    @Patch(className = "org.lwjglx.opengl.Display", methodName = "swapBuffers")
    public static class Patch_swapBuffers {
        @Patch.OnEnter
        public static void enter() {
            try {
                Capture.beforeSwap();
            } catch (Throwable e) {
                Capture.failed(e);
            }
        }
    }

    // 1.0.8: the aim point. The game turns the character to AimingReticle.getXA/getYA (the real mouse); while
    // Test Ground has set a point (Aim.set) these return it. getX/getY multiply getXA/getYA by the zoom, so
    // everything after is the game's own.
    @Patch(className = "zombie.input.AimingReticle", methodName = "getXA")
    public static class Patch_aimX {
        @Patch.OnExit
        public static void exit(@Patch.Argument(0) int idx, @Patch.Return(readOnly = false) int ret) {
            ret = Aim.ax(ret, idx);
        }
    }

    @Patch(className = "zombie.input.AimingReticle", methodName = "getYA")
    public static class Patch_aimY {
        @Patch.OnExit
        public static void exit(@Patch.Argument(0) int idx, @Patch.Return(readOnly = false) int ret) {
            ret = Aim.ay(ret, idx);
        }
    }
}
