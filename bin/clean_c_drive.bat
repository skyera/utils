@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0clean_c_drive.ps1" %*
