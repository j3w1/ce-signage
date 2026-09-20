@echo off
chcp 65001 >nul
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\ProgramData\Casa Elida\Anuncios\Control de Anuncios.ps1" -Accion Estado
