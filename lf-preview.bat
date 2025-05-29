@echo off
REM Use bat to preview the file with paging and syntax highlighting
REM lf passes the file path as the first argument

bat --style="plain,numbers" --color=always --paging=never "%1"
