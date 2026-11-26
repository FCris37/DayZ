@echo off
title 1-INSTALAR-O-ACTUALIZAR
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\instalar.ps1" %*
echo.
pause
