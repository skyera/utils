#!/bin/sh
case "$1" in
    *.tar|*.tar.gz|*.tar.bz2|*.tar.xz|*.tgz|*.tbz2|*.txz)
        tar -tf "$1" | head -n 20
        ;;
    *.zip)
        unzip -l "$1" | head -n 20
        ;;
    *.rar)
        unrar l "$1" | head -n 20
        ;;
    *.7z)
        7z l "$1" | head -n 20
        ;;
    *.pdf)
        pdftotext "$1" - | head -n 20
        ;;
    *.png|*.jpg|*.jpeg|*.gif|*.bmp|*.webp|*.heic|*.avif)
        chafa --size="${2:-40}x${3:-20}" --colors=full "$1"
        ;;
    *)
        if [ -d "$1" ]; then
            ls -F --color=always "$1"
        elif [ -L "$1" ]; then
            ls -ld --color=always "$1"
        else
            case $(file -bi "$1") in
                text/*|application/json*|application/javascript*)
                    bat --style="plain,numbers" --color=always --paging=never "$1"
                    ;;
                *)
                    file -b "$1"
                    ;;
            esac
        fi
        ;;
esac
