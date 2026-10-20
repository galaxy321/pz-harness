package pzmod.tgmemory;

import org.lwjgl.opengl.GL;
import org.lwjgl.opengl.GL11;
import org.lwjgl.opengl.GLCapabilities;

// Runs on the render thread (queued by Sampler). Values from GL are in KB.
final class Vram {
    static final int NVX_DEDICATED = 0x9047;      // GL_GPU_MEMORY_INFO_DEDICATED_VIDMEM_NVX
    static final int NVX_CURRENT_FREE = 0x9049;   // GL_GPU_MEMORY_INFO_CURRENT_AVAILABLE_VIDMEM_NVX
    static final int ATI_TEXTURE_FREE = 0x87FC;   // GL_TEXTURE_FREE_MEMORY_ATI: 4 ints, [0] = free KB

    static void query(boolean reset) {
        GLCapabilities caps = GL.getCapabilities();
        if (caps.GL_NVX_gpu_memory_info) {
            int total = GL11.glGetInteger(NVX_DEDICATED);
            int free = GL11.glGetInteger(NVX_CURRENT_FREE);
            Sampler.setVram("nvx", total / 1024.0, free / 1024.0, reset);
        } else if (caps.GL_ATI_meminfo) {
            int[] v = new int[4];
            GL11.glGetIntegerv(ATI_TEXTURE_FREE, v);
            Sampler.setVram("ati", -1, v[0] / 1024.0, reset);
        } else {
            Sampler.setVram("none (this GPU's driver reports no free VRAM)", -1, -1, reset);
        }
    }
}
