@echo off
REM Launcher for envlog.ps1 that bypasses PowerShell's execution policy.
REM Usage:  envlog              (env-logs input.lua -> out.lua)
REM         envlog myscript.lua (env-logs that file  -> out.lua)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0envlog.ps1" %*
