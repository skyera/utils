@echo off
setlocal
set "ARG1=%~1"
if "%ARG1%"=="-" set "ARG1=dec"
if "%ARG1%"=="+" set "ARG1=inc"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0opacity.ps1" "%ARG1%" %2 %3 %4 %5 %6 %7 %8 %9

