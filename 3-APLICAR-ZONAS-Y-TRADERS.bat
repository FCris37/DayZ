@echo off
title 3-APLICAR-ZONAS-Y-TRADERS
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\configurar_zonas.ps1" %*
echo.
pause
