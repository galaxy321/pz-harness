$l='C:\Users\tony6\Zomboid\perf-logs'; $q="$l\queue-notes.txt"; $j="$l\tg-job.ps1"; $z='C:\Users\tony6\Zomboid'; $b="$l\mod-backups"
function N($m){ Add-Content $q "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') chain33: $m" }
function Install {
    Remove-Item "$z\mods\TestGround","$z\mods\TestGroundAutorun","$z\mods\TestGroundCapture" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Copy-Item "$b\ship11341\TestGround" "$z\mods\TestGround" -Recurse; Copy-Item "$b\autorun1520\TestGroundAutorun" "$z\mods\TestGroundAutorun" -Recurse
    Copy-Item "$b\ship11341\TestGroundCapture" "$z\mods\TestGroundCapture" -Recurse
    Copy-Item "$l\benchmark-check\default.txt.bench" "$z\mods\default.txt" -Force
}
function Restore {
    Remove-Item "$z\mods\TestGround","$z\mods\TestGroundAutorun","$z\mods\TestGroundCapture" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
    Copy-Item "$b\tg1132\TestGround" "$z\mods\TestGround" -Recurse; Copy-Item "$b\autorun144\TestGroundAutorun" "$z\mods\TestGroundAutorun" -Recurse
    Copy-Item "$l\benchmark-check\default.txt.before" "$z\mods\default.txt" -Force
    [IO.File]::WriteAllText("$z\Lua\TestGround_autorun.txt", '')
}
# Two shooting runs at whatever resolution the game comes up in; a run below 2560x1440 is renamed "-diag".
N "shooting-11341 x2 (TG 1.13.41 + Autorun 1.5.20, Capture 1.0.8; test copy without CHStatusHUD)"
for ($k = 1; $k -le 2; $k++) {
    if (Get-Process ProjectZomboid64 -EA SilentlyContinue) { N "game running, waiting 5 min"; Start-Sleep 300; $k--; continue }
    Install
    & "$l\reset-perftest-save.ps1" -Profiler none -ExtraMods TestGroundCapture -RemoveMods CHStatusHUD | Out-File -Append "$l\chain33-reset.log"
    $name = "shooting-11341-$k"; if (Test-Path "$l\$name") { Remove-Item "$l\$name" -Recurse -Force -Confirm:$false }
    & $j -Name $name -TimeoutMin 12 -MinWidth 1 -CloseWaitS 150 -Flag @('save = Lumberjack - Copy - PerfTest','mode = Sandbox','delay = 20','quit = 0','endscreen = 1','plan = shooting')
    Start-Sleep 15; Restore
    $m = Select-String -Path "$l\$name\run.log" -Pattern 'Initial resolution (\d+)x' | Select-Object -First 1
    if ($m -and [int]$m.Matches[0].Groups[1].Value -lt 2560) { Rename-Item "$l\$name" "$name-diag"; N "$name ran below 2560x1440, labelled diagnostic" }
}
N "normal setup restored"
N "finished"
