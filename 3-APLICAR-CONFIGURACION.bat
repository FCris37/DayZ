@echo off
title 3-APLICAR-CONFIGURACION
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\configurar.ps1" %*
echo.
pause
