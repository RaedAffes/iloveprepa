@echo off
where node >nul 2>nul
if errorlevel 1 (
  echo Node.js is not installed on this computer.
  echo Install it from https://nodejs.org/ ^(the LTS version^), then run this file again.
  pause
  exit /b 1
)
node "%~dp0upload.mjs"
pause
