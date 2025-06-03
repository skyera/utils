@echo off
REM Use bat for text files and chafa for images
REM lf passes the file path as the first argument

set "FILE=%1"

REM Check file extension (case-insensitive)
if /i "%FILE:~-4%"==".png"  goto :image
if /i "%FILE:~-4%"==".jpg"  goto :image
if /i "%FILE:~-5%"==".jpeg" goto :image
if /i "%FILE:~-4%"==".gif"  goto :image
if /i "%FILE:~-4%"==".bmp"  goto :image

REM Default to bat for text files
bat --style="numbers" --color=always --paging=never "%FILE%" 2> bat-error.log
goto :eof

:image
REM Use chafa for image files
chafa --size=40x20 --colors=full "%FILE%"
goto :eof
