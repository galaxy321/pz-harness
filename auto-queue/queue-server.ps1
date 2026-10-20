# Live PC queue page on http://localhost:8000/ (localhost only, no auth). Reads the same files the queue already writes:
# pc-queue.md (the table), queue-notes.txt (chain log), the newest run folder's run.log, and whether the game is running.
# The page polls /state every 5 s, so it updates without a refresh.
param([int]$Port = 8000)
$logs = "C:\Users\tony6\Zomboid\perf-logs"
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add("http://localhost:$Port/"); $l.Prefixes.Add("http://127.0.0.1:$Port/")
$l.Start()
function Tail($p, $n) { if (Test-Path $p) { [string[]]@([IO.File]::ReadAllLines($p) | Select-Object -Last $n) } else { [string[]]@() } }
function State {
    $g = Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue | Select-Object -First 1
    $run = Get-ChildItem $logs -Directory -ErrorAction SilentlyContinue | Where-Object { Test-Path (Join-Path $_.FullName "run.log") } | Sort-Object CreationTime | Select-Object -Last 1
    $runLog = if ($run) { Tail (Join-Path $run.FullName "run.log") 12 } else { @() }
    $done = [bool]($runLog -match 'result:')
    # estimated finish: queue-plan.json lists the remaining items (name, run-folder regex, minutes). An item is finished
    # when a folder matching it has "result:" in run.log; the one in progress counts its minutes minus elapsed time.
    $eta = @(); $t = Get-Date
    $planFile = Join-Path $logs "queue-plan.json"
    if (Test-Path $planFile) {
        $dirs = @(Get-ChildItem $logs -Directory -ErrorAction SilentlyContinue)
        foreach ($it in ([IO.File]::ReadAllText($planFile) | ConvertFrom-Json)) {
            $d = $dirs | Where-Object { $_.Name -match $it.match } | Sort-Object CreationTime | Select-Object -Last 1
            $fin = $d -and (Select-String (Join-Path $d.FullName "run.log") -Pattern 'result:' -Quiet -ErrorAction SilentlyContinue)
            if ($fin) { $eta += [ordered]@{ name = $it.name; state = "done"; at = (Get-Item (Join-Path $d.FullName "run.log")).LastWriteTime.ToString("HH:mm") }; continue }
            $left = [double]$it.minutes
            $st = "pending"
            if ($d) { $st = "running"; $left = [Math]::Max(2, $it.minutes - ((Get-Date) - $d.CreationTime).TotalMinutes) }
            $t = $t.AddMinutes($left)
            $eta += [ordered]@{ name = $it.name; state = $st; at = $t.ToString("HH:mm") }
        }
    }
    [ordered]@{
        eta      = $eta
        finish   = $t.ToString("ddd HH:mm")
        now      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        game     = [bool]$g
        gameSince = if ($g) { $g.StartTime.ToString("HH:mm:ss") } else { $null }
        hold     = (Test-Path (Join-Path $logs "HOLD"))
        run      = if ($run) { $run.Name } else { $null }
        runStart = if ($run) { $run.CreationTime.ToString("HH:mm") } else { $null }
        runDone  = $done
        runLog   = $runLog
        notes    = Tail (Join-Path $logs "queue-notes.txt") 10
        queueMd  = if (Test-Path (Join-Path $logs "pc-queue.md")) { [IO.File]::ReadAllText((Join-Path $logs "pc-queue.md")) } else { "" }
    } | ConvertTo-Json -Depth 4
}
while ($l.IsListening) {
    try {
        $c = $l.GetContext(); $path = $c.Request.Url.AbsolutePath
        if ($path -eq "/state") { $body = State; $type = "application/json; charset=utf-8" }
        elseif ($path -eq "/") { $body = [IO.File]::ReadAllText((Join-Path $logs "queue-page.html")); $type = "text/html; charset=utf-8" }
        else { $c.Response.StatusCode = 404; $body = "not found"; $type = "text/plain" }
        $b = [Text.Encoding]::UTF8.GetBytes($body)
        $c.Response.ContentType = $type; $c.Response.Headers.Add("Cache-Control", "no-store")
        $c.Response.OutputStream.Write($b, 0, $b.Length); $c.Response.Close()
    } catch { try { $e = [Text.Encoding]::UTF8.GetBytes("{""error"": ""$($_.Exception.Message -replace '"', '')""}"); $c.Response.StatusCode = 500; $c.Response.OutputStream.Write($e, 0, $e.Length); $c.Response.Close() } catch { }; Start-Sleep -Milliseconds 200 }
}
