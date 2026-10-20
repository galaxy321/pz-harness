// 1.0.8: the aim patches through ZombieBuddy's own engine on a stub of zombie.input.AimingReticle (public static int getXA(int), getYA(int), getX(int) = getXA * 2).
// Needs ZombieBuddy.jar, tgcapture.jar and a classes folder for zombie.Lua.LuaManager on the class path, and -Djdk.attach.allowAttachSelf=true.
public class AimPatchTest {
    public static void main(String[] a) throws Exception {
        java.lang.instrument.Instrumentation in = net.bytebuddy.agent.ByteBuddyAgent.install();
        java.lang.reflect.Field f = me.zed_0xff.zombie_buddy.Loader.class.getDeclaredField("g_instrumentation"); f.setAccessible(true); f.set(null, in);
        me.zed_0xff.zombie_buddy.PatchEngine.applyPatches("pzmod.tgcapture", T.class.getClassLoader());
        System.out.println("before: " + zombie.input.AimingReticle.getXA(0) + "," + zombie.input.AimingReticle.getYA(0));
        pzmod.tgcapture.Aim.set(0, 500, 600);
        System.out.println("on: " + zombie.input.AimingReticle.getXA(0) + "," + zombie.input.AimingReticle.getYA(0) + " getX=" + zombie.input.AimingReticle.getX(0) + " other player: " + zombie.input.AimingReticle.getXA(1));
        Thread.sleep(700);
        System.out.println("stale: " + zombie.input.AimingReticle.getXA(0) + "," + zombie.input.AimingReticle.getYA(0));
        pzmod.tgcapture.Aim.set(0, 7, 8); pzmod.tgcapture.Aim.clear();
        System.out.println("cleared: " + zombie.input.AimingReticle.getXA(0));
        System.out.println(pzmod.tgcapture.Aim.status());
    }
}
