@echo off
title Folder Colors installer
echo Installing Folder Colors (per-user, no admin rights)...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-FolderColors.ps1" -ClassicMenu
echo.
pause
