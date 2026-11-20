@echo off
REM pc-optimizer: ejecuta el diagnostico (solo lectura) y guarda los JSON en ..\_resultados
setlocal
set "DIR=%~dp0"
set "OUT=%DIR%..\_resultados"
if not exist "%OUT%" mkdir "%OUT%"
echo [1/4] Hardware (unos 5 segundos)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%hardware.ps1" -OutFile "%OUT%\hardware.json" > "%OUT%\hardware.log" 2>&1
echo [2/4] Software y arranque...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%software.ps1" -OutFile "%OUT%\software.json" > "%OUT%\software.log" 2>&1
echo [3/4] Espacio en disco (hasta 2 minutos)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%disco.ps1" -OutFile "%OUT%\disco.json" > "%OUT%\disco.log" 2>&1
echo [4/4] Herramientas de desarrollo (hasta 3 minutos)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%DIR%dev-caches.ps1" -OutFile "%OUT%\dev-caches.json" > "%OUT%\dev-caches.log" 2>&1
echo.
echo Listo. Resultados en: %OUT%
timeout /t 5 >nul
