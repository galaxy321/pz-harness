# Recreates the PerfTest save from "Lumberjack - Copy" so every run starts byte-identical.
# Usage:  powershell -ExecutionPolicy Bypass -File reset-perftest-save.ps1 -Profiler none|v1|v2
# Only ever deletes "Lumberjack - Copy - PerfTest". The source save is read, never written.
param([ValidateSet("none", "v1", "v2")][string]$Profiler = "v1", [string[]]$ExtraMods = @(), [string[]]$RemoveMods = @(), [switch]$NoSaveMods, [string]$Source = "Lumberjack - Copy", [string]$ModsFile = "")

$ErrorActionPreference = "Stop"
$saves = "C:\Users\tony6\Zomboid\Saves\Sandbox"
$src = Join-Path $saves $Source
$dst = Join-Path $saves "$Source - PerfTest"

if (Get-Process ProjectZomboid64 -ErrorAction SilentlyContinue) { throw "Close Project Zomboid first." }
if (-not (Test-Path (Join-Path $src "mods.txt"))) { throw "Source save not found: $src" }

if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
Copy-Item $src $dst -Recurse

$add = @("TestGround", "TestGroundAutorun")
if (Test-Path "C:\Users\tony6\Zomboid\mods\TestGroundBridge\42\mod.info") { $add = @("TestGround", "TestGroundBridge", "TestGroundAutorun") }
if ($Profiler -eq "v1") { $add = @("LuaEventProfiler") + $add }
if ($Profiler -eq "v2") { $add = @("LuaEventProfiler2") + $add }
$add = $add + $ExtraMods

$f = Join-Path $dst "mods.txt"
$raw = [IO.File]::ReadAllText($f)
if ($ModsFile) { $raw = [IO.File]::ReadAllText($ModsFile); Write-Host "mods.txt replaced by $ModsFile" }
if ($NoSaveMods) { $raw = [regex]::Replace($raw, "(?m)^\s*mod = [^\r\n]*,\r?\n", ""); Write-Host "removed all of the save's mods" }
foreach ($rm in $RemoveMods) {
    $raw = [regex]::Replace($raw, "(?m)^\s*mod = " + [regex]::Escape($rm) + ",\r?\n", "")
    Write-Host "removed mod $rm"
}
$nl =if ($raw -match "`r`n") { "`r`n" } else { "`n" }
$end = $raw.IndexOf("$nl}", $raw.IndexOf("mods$nl{"))
if ($end -lt 0) { throw "Could not find the end of the mods block in $f" }
$add = @($add | Where-Object { $raw -notmatch ("(?m)^\s*mod = " + [regex]::Escape($_) + ",") })
$top = @($add | Where-Object { $_ -eq "ChunkLoadSieveDev" }); $add = @($add | Where-Object { $_ -ne "ChunkLoadSieveDev" })   # the dev sieve must load above the mods it filters (LGEE, RCSF, VFE), so it goes to the top of the list
$ins = ($add | ForEach-Object { "$nl    mod = $_," }) -join ""
$raw = $raw.Insert($end, $ins); if ($top) { $start = $raw.IndexOf("mods$nl{") + ("mods$nl{").Length; $raw = $raw.Insert($start, (($top | ForEach-Object { "$nl    mod = $_," }) -join "")) }
[IO.File]::WriteAllText($f, $raw, (New-Object Text.UTF8Encoding $false))

$a = Get-ChildItem $src -Recurse -File | Measure-Object Length -Sum
$b = Get-ChildItem $dst -Recurse -File | Measure-Object Length -Sum
Write-Host "PerfTest save rebuilt ($($b.Count) files; source $($a.Count)). Added mods: $($add -join ', ')"


