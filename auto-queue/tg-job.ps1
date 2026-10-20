# Unattended Test Ground job (19 Oct 2026): writes the Autorun flag, launches the game muted, waits for the done file or
# the game exiting, closes the game if it is still up, copies the result files into perf-logs\<Name>\.
# No screen capture of any kind (project rule); shots come from the game itself.
param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string[]]$Flag, [int]$TimeoutMin = 30, [int]$MinWidth = 0, [int]$CloseWaitS = 40)
$resChecked = $false
$zd = 'C:\Users\tony6\Zomboid'; $logs = "$zd\perf-logs"; $game = 'C:\Program Files (x86)\Steam\steamapps\common\ProjectZomboid'
$out = Join-Path $logs $Name; New-Item -ItemType Directory -Force $out | Out-Null
function Log($m) { $l = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m"; Add-Content (Join-Path $out 'run.log') $l; Add-Content (Join-Path $logs 'queue-notes.txt') "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ${Name}: $m" }
if (Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue) { Log "game already running; job not started"; exit 1 }
$done = "$zd\Lua\TestGround_autorun_done.txt"; $flagFile = "$zd\Lua\TestGround_autorun.txt"
if (Test-Path $done) { Remove-Item $done -Force }
[IO.File]::WriteAllText($flagFile, (($Flag -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
Log ("flag: " + ($Flag -join ' | '))
$muteFlag = Join-Path $out 'unmute.flag'
$muter = Start-Process powershell -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $out 'mute.log') -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$logs\pz-mute.ps1`"", '-FlagFile', "`"$muteFlag`"")
$t0 = Get-Date
Start-Process (Join-Path $game 'ProjectZomboid64.exe') -WorkingDirectory $game | Out-Null
Log "game launched"
$result = 'timeout'
while ((Get-Date) -lt $t0.AddMinutes($TimeoutMin)) {
    Start-Sleep -Seconds 5
    # a done file counts only with a "result =" line (a late ui_check_late append can recreate it as a stub)
    if ((Test-Path $done) -and (Select-String $done -Pattern '^result = ' -Quiet)) { $result = 'done file'; Start-Sleep -Seconds 20; break }
    if ($MinWidth -and -not $resChecked -and (Test-Path "$zd\console.txt") -and (Get-Item "$zd\console.txt").LastWriteTime -gt $t0) {
        $m = Select-String "$zd\console.txt" -Pattern 'Initial resolution (\d+)x(\d+)' | Select-Object -First 1
        if ($m) {
            $resChecked = $true; $w = [int]$m.Matches[0].Groups[1].Value; Log "display: $($m.Line.Trim())"
            if ($w -lt $MinWidth) { $result = "refused: resolution $w wide, below $MinWidth"; Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue | Stop-Process -Force; break }
        }
    }
    if (((Get-Date) - $t0).TotalSeconds -gt 90 -and -not (Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue)) { $result = 'game exited'; break }
}
Log "wait ended: $result after $([math]::Round(((Get-Date) - $t0).TotalSeconds)) s"
$p = Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue
if ($p) { Start-Sleep -Seconds $CloseWaitS; $p = Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue; if ($p) { $p | Stop-Process -Force; Log "game closed by the job" } }
Start-Sleep -Seconds 3; New-Item $muteFlag -ItemType File -Force | Out-Null
if (Test-Path $done) { Copy-Item $done $out; Get-Content $done | ForEach-Object { Log "  done: $_" } } else { Log "no done file" }
Copy-Item "$zd\console.txt" $out -ErrorAction SilentlyContinue
Get-ChildItem "$zd\Lua" -Filter 'TestGround_*' | Where-Object { $_.LastWriteTime -gt $t0 } | Copy-Item -Destination $out
Log "job finished"
