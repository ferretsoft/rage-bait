@echo off
REM Run the auditor voice generator from this script's directory so the path always works.
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0generate_auditor_voice.ps1"
pause
