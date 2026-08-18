# envlog.ps1
#
# Env-logs a Lua script with the 69ms httplog2 logger. The full trace is written
# to out.lua; the console only prints "done in <n> seconds".
#
# Usage:
#   .\envlog.ps1                # env-logs input.lua  -> out.lua
#   .\envlog.ps1 myscript.lua   # env-logs myscript.lua -> out.lua

param(
    [string]$File = "input.lua"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Get-Command lune -ErrorAction SilentlyContinue)) {
    Write-Error "Lune is not on PATH. Install it or add lune.exe to PATH."
    exit 1
}

if (-not (Test-Path $File)) {
    Write-Error "Input file '$File' was not found."
    exit 1
}

$name = Split-Path $File -Leaf

# The logger reads from dumps\original\ and writes to dumps\dumped\ (CWD-relative).
New-Item -ItemType Directory -Force -Path "dumps\original" | Out-Null
New-Item -ItemType Directory -Force -Path "dumps\dumped"   | Out-Null
Copy-Item -Force $File "dumps\original\$name"

# Run the logger with all of its console output suppressed (it still writes the
# full trace to dumps\dumped\<name>). Time the run.
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = "Continue"
& lune run 69ms/httplog2.lua $name 2>&1 | Out-Null
$exit = $LASTEXITCODE
$ErrorActionPreference = $prevEAP
$sw.Stop()

$dumped = Join-Path "dumps\dumped" ([IO.Path]::GetFileNameWithoutExtension($name) + ".lua")
if (($exit -ne 0) -or (-not (Test-Path $dumped))) {
    Write-Error "envlog failed (lune exit $exit). For details run:  lune run 69ms/httplog2.lua $name"
    exit 1
}

Copy-Item -Force $dumped "out.lua"
$secs = [math]::Round($sw.Elapsed.TotalSeconds, 2)
Write-Host "done in $secs seconds"
