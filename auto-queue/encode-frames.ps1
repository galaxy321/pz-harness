# Showcase film (game-side frames): turn Test Ground Capture's film frames into one clip per step,
# each under 18 MB for the project upload. Expects <FilmDir>\frames.txt with one line per frame
# "<seq> <epoch ms> <tag> <file>" (Test Ground Capture 1.0.2 film mode; tags settle, gap and each step's,
# and only the steps are encoded) and the
# JPEG frames next to it. Frame durations come from the timestamps, so dropped frames keep real time.
#   powershell -ExecutionPolicy Bypass -File encode-frames.ps1 -FilmDir <...\Zomboid\Lua\film\<run>> [-MaxMB 18]
param(
  [Parameter(Mandatory = $true)][string]$FilmDir,
  [string]$Out = "$env:USERPROFILE\Zomboid\showcase\upload",
  [double]$MaxMB = 18,
  [string]$FFmpeg = ""
)
$ErrorActionPreference = "Stop"
if (-not $FFmpeg) { $FFmpeg = (Get-Command ffmpeg).Source }
New-Item -ItemType Directory -Force $Out | Out-Null
$frames = @{}; $order = @()
foreach ($l in Get-Content (Join-Path $FilmDir "frames.txt")) {
  $f = $l.Trim() -split '\s+'
  if ($f.Count -lt 4 -or $f[0] -eq "#") { continue }
  if ($f[2] -eq "settle" -or $f[2] -eq "gap") { continue }   # only the steps go in the film
  $tag = ($f[2] -replace '[^\w\-]', '_')
  if (-not $frames.ContainsKey($tag)) { $frames[$tag] = New-Object System.Collections.ArrayList; $order += $tag }
  [void]$frames[$tag].Add(@{ ms = [double]$f[1]; file = (Join-Path $FilmDir $f[3]) })
}
$inv = [Globalization.CultureInfo]::InvariantCulture
$i = 0
foreach ($tag in $order) {
  $list = $frames[$tag]; if ($list.Count -lt 2) { continue }
  $i++
  $cc = Join-Path $Out ("{0}-{1}.ffconcat" -f $i, $tag)
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine("ffconcat version 1.0")
  for ($k = 0; $k -lt $list.Count; $k++) {
    $d = if ($k -lt $list.Count - 1) { [math]::Min(1.0, ($list[$k + 1].ms - $list[$k].ms) / 1000) } else { 0.033 }
    [void]$sb.AppendLine("file '" + ($list[$k].file -replace "'", "'\''") + "'")
    [void]$sb.AppendLine("duration " + $d.ToString("0.000", $inv))
  }
  [void]$sb.AppendLine("file '" + ($list[$list.Count - 1].file -replace "'", "'\''") + "'")
  [IO.File]::WriteAllText($cc, $sb.ToString())
  $secs = ($list[$list.Count - 1].ms - $list[0].ms) / 1000 + 0.1
  $kbps = [math]::Floor($MaxMB * 8192 / $secs * 0.92)
  $clip = Join-Path $Out ("{0}-{1}.mp4" -f $i, $tag)
  & $FFmpeg -hide_banner -loglevel error -y -f concat -safe 0 -i $cc -vf "fps=30,scale=1280:-2,format=yuv420p" -c:v libx264 -preset slow -b:v "${kbps}k" -maxrate "$([math]::Floor($kbps*1.3))k" -bufsize "$($kbps*2)k" -movflags +faststart $clip
  Write-Output ("{0}: {1} frames, {2:N1} s, {3:N1} MB" -f $tag, $list.Count, $secs, ((Get-Item $clip).Length / 1MB))
}
Copy-Item (Join-Path $FilmDir "frames.txt") $Out
Write-Output "clips in $Out; upload them to /mnt/project-files/showcase/raw/"
