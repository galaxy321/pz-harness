$l='C:\Users\tony6\Zomboid\perf-logs'; $q="$l\queue-notes.txt"; $j="$l\tg-job.ps1"; $z='C:\Users\tony6\Zomboid'; $b="$l\mod-backups"
function N($m){ Add-Content $q "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') chain34: $m" }
if (Get-Process ProjectZomboid64 -EA SilentlyContinue) { N "game running, not started"; exit 1 }
N "showcase3 on TG 1.13.41 + Autorun 1.5.20 + Capture 1.0.8 + Crane Test Ground 0.2.1"
Remove-Item "$z\mods\TestGround","$z\mods\TestGroundAutorun","$z\mods\TestGroundCapture","$z\mods\CraneTestGround" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
Copy-Item "$b\ship11341\TestGround" "$z\mods\TestGround" -Recurse; Copy-Item "$b\autorun1520\TestGroundAutorun" "$z\mods\TestGroundAutorun" -Recurse
Copy-Item "$b\ship11341\TestGroundCapture" "$z\mods\TestGroundCapture" -Recurse
Copy-Item "$b\crane021\CraneTestGround" "$z\mods\CraneTestGround" -Recurse
Copy-Item "$l\benchmark-check\default.txt.bench" "$z\mods\default.txt" -Force
$plan = "$z\Lua\TestGround_showcase.txt"; if (Test-Path $plan) { Copy-Item $plan "$l\showcase3-plan.before.txt" -Force }
Copy-Item "$l\showcase\TestGround_showcase.showcase3.txt" $plan -Force
& "$l\reset-perftest-save.ps1" -Profiler none -ExtraMods TestGroundCapture,CraneTestGround -RemoveMods CHStatusHUD | Out-File -Append "$l\chain34-reset.log"
$t0 = Get-Date
& $j -Name 'showcase3' -TimeoutMin 20 -MinWidth 2560 -CloseWaitS 60 -Flag @('save = Lumberjack - Copy - PerfTest','mode = Sandbox','plan = TestGround_showcase.txt','delay = 20','timeout = 900','quit = 1','addmods = CraneTestGround','closeui = 1')
Start-Sleep 15
# normal setup (Crane Test Ground 0.2.1 stays installed: the play save lists it)
Remove-Item "$z\mods\TestGround","$z\mods\TestGroundAutorun","$z\mods\TestGroundCapture" -Recurse -Force -Confirm:$false -ErrorAction SilentlyContinue
Copy-Item "$b\tg1132\TestGround" "$z\mods\TestGround" -Recurse; Copy-Item "$b\autorun144\TestGroundAutorun" "$z\mods\TestGroundAutorun" -Recurse
Copy-Item "$l\benchmark-check\default.txt.before" "$z\mods\default.txt" -Force
[IO.File]::WriteAllText("$z\Lua\TestGround_autorun.txt", '')
N "normal setup restored (Crane Test Ground 0.2.1 kept)"
$film = Get-ChildItem "$z\Lua\film" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $t0 } | Sort-Object LastWriteTime | Select-Object -Last 1
if ($film) {
    N "encoding $($film.Name)"
    & "$l\showcase\encode-frames.ps1" -FilmDir $film.FullName -Out "$l\showcase3\clips" -FFmpeg "$l\tools\ffmpeg\x\ffmpeg-9.0.2-essentials_build\bin\ffmpeg.exe" *>> "$l\showcase3\encode.log"
    N "encoded into showcase3\clips"
} else { N "no film folder found" }
N "finished"
