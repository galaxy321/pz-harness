# Per-process mute for automated runs: mutes every Windows audio session of ProjectZomboid64 (all render devices)
# once they appear, keeps them muted, and UNMUTES them when $FlagFile appears (run-perf writes it before closing the game)
# or when -Unmute is given. Only the game's own sessions are touched; nothing else on the PC.
param([string]$FlagFile = "", [switch]$Unmute, [string]$ProcessName = "ProjectZomboid64")
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class MMDeviceEnumeratorCo {}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator { int EnumAudioEndpoints(int dataFlow, int stateMask, out IMMDeviceCollection devices); int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice device); }
[Guid("0BD7A1BE-7A1A-44DB-8397-CC5392387B5E"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceCollection { int GetCount(out int count); int Item(int index, out IMMDevice device); }
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice { int Activate(ref Guid iid, int clsCtx, IntPtr activationParams, [MarshalAs(UnmanagedType.IUnknown)] out object iface); }
[Guid("77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionManager2 { int GetAudioSessionControl(IntPtr a, int b, out IntPtr c); int GetSimpleAudioVolume(IntPtr a, int b, out IntPtr c); int GetSessionEnumerator(out IAudioSessionEnumerator e); }
[Guid("E2F5BB11-0570-40CA-ACDD-3AA01277DEE8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionEnumerator { int GetCount(out int count); int GetSession(int index, out IAudioSessionControl2 session); }
[Guid("bfb7ff88-7239-4fc9-8fa2-07c950be9c6d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioSessionControl2 {
  int GetState(out int s); int GetDisplayName(out IntPtr n); int SetDisplayName(string n, ref Guid g); int GetIconPath(out IntPtr p); int SetIconPath(string p, ref Guid g);
  int GetGroupingParam(out Guid g); int SetGroupingParam(ref Guid g, ref Guid c); int RegisterAudioSessionNotification(IntPtr n); int UnregisterAudioSessionNotification(IntPtr n);
  int GetSessionIdentifier(out IntPtr s); int GetSessionInstanceIdentifier(out IntPtr s); int GetProcessId(out uint pid); int IsSystemSoundsSession(); int SetDuckingPreference(bool o); }
[Guid("87CE5498-68D6-44E5-9215-6DA47EF883D8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface ISimpleAudioVolume { int SetMasterVolume(float l, ref Guid g); int GetMasterVolume(out float l); int SetMute(bool m, ref Guid g); int GetMute(out bool m); }
public static class GameMute {
  // returns the number of the process's sessions set to the requested state, over all active render devices
  // number of the process's sessions that are currently muted, and the total
  public static int[] State(uint pid) {
    int muted = 0, total = 0; var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCo(); IMMDeviceCollection devs; en.EnumAudioEndpoints(0, 1, out devs);
    int dc; devs.GetCount(out dc);
    for (int d = 0; d < dc; d++) {
      IMMDevice dev; devs.Item(d, out dev); object o; Guid iid = typeof(IAudioSessionManager2).GUID;
      if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) continue;
      var mgr = (IAudioSessionManager2)o; IAudioSessionEnumerator se; mgr.GetSessionEnumerator(out se); int sc; se.GetCount(out sc);
      for (int i = 0; i < sc; i++) {
        IAudioSessionControl2 s; se.GetSession(i, out s); uint p; s.GetProcessId(out p);
        if (p != pid) continue;
        bool m; ((ISimpleAudioVolume)s).GetMute(out m); total++; if (m) muted++;
      }
    }
    return new int[] { muted, total };
  }
  public static int Set(uint pid, bool mute) {
    int n = 0; var en = (IMMDeviceEnumerator)new MMDeviceEnumeratorCo(); IMMDeviceCollection devs; en.EnumAudioEndpoints(0, 1, out devs);
    int dc; devs.GetCount(out dc);
    for (int d = 0; d < dc; d++) {
      IMMDevice dev; devs.Item(d, out dev); object o; Guid iid = typeof(IAudioSessionManager2).GUID;
      if (dev.Activate(ref iid, 23, IntPtr.Zero, out o) != 0) continue;
      var mgr = (IAudioSessionManager2)o; IAudioSessionEnumerator se; mgr.GetSessionEnumerator(out se); int sc; se.GetCount(out sc);
      for (int i = 0; i < sc; i++) {
        IAudioSessionControl2 s; se.GetSession(i, out s); uint p; s.GetProcessId(out p);
        if (p != pid) continue;
        var v = (ISimpleAudioVolume)s; Guid g = Guid.Empty; v.SetMute(mute, ref g); n++;
      }
    }
    return n;
  }
}
"@
function Pids { @(Get-Process $ProcessName -ErrorAction SilentlyContinue | ForEach-Object { [uint32]$_.Id }) }
if ($Unmute) { foreach ($id in Pids) { $n = [GameMute]::Set($id, $false); Write-Host "unmuted $n session(s) of pid $id" }; return }
while (-not (Pids)) { Start-Sleep 1 }
$muted = 0
# before the first mute: log whether the game's sessions came up already muted (would mean Windows kept the last mute)
$t0 = Get-Date
while (($ids = Pids) -and ((Get-Date) - $t0).TotalSeconds -lt 30) {
    $st = [GameMute]::State($ids[0]); if ($st[1] -gt 0) { Write-Host "$(Get-Date -Format HH:mm:ss.fff) initial state: $($st[0]) of $($st[1]) session(s) already muted"; break }
    Start-Sleep -Milliseconds 200
}
# every 0.5 s: any session the game opens later (world load, new device) is muted within half a second
while ($ids = Pids) {
    if ($FlagFile -and (Test-Path $FlagFile)) { foreach ($id in $ids) { $n = [GameMute]::Set($id, $false); Write-Host "$(Get-Date -Format HH:mm:ss.fff) unmuted $n session(s)" }; return }
    foreach ($id in $ids) { try { $n = [GameMute]::Set($id, $true); if ($n -ne $muted) { $muted = $n; Write-Host "$(Get-Date -Format HH:mm:ss.fff) muted $n session(s) of pid $id" } } catch { } }
    Start-Sleep -Milliseconds 500
}
