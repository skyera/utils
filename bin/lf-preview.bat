@echo off
REM Use bat for text files and chafa for images
REM lf passes the file path as the first argument, width as second, height as third

set "FILE=%1"
set "WIDTH=%2"
set "HEIGHT=%3"

if "%WIDTH%"=="" set "WIDTH=40"
if "%HEIGHT%"=="" set "HEIGHT=20"

REM Check file extension (case-insensitive) using %~x1
set "EXT=%~x1"

if /i "%EXT%"==".png"  goto :image
if /i "%EXT%"==".jpg"  goto :image
if /i "%EXT%"==".jpeg" goto :image
if /i "%EXT%"==".gif"  goto :image
if /i "%EXT%"==".bmp"  goto :image

REM Default to bat for text files
bat --style="plain,numbers" --color=always --paging=never "%FILE%" 2>nul
goto :eof

:image
REM Use chafa for image files with dynamic dimensions
chafa --size=%WIDTH%x%HEIGHT% --colors=full "%FILE%"
goto :eof
