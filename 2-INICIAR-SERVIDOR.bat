@echo off
title 2-INICIAR-SERVIDOR
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\iniciar.ps1" %*
echo.
pause
