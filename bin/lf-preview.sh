#!/bin/sh

# Get dimensions, default to 40x20 if not provided
WIDTH=${2:-40}
HEIGHT=${3:-20}

# Ensure dimensions are at least 1x1 to prevent chafa errors
[ "$WIDTH" -lt 1 ] && WIDTH=1
[ "$HEIGHT" -lt 1 ] && HEIGHT=1

case "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" in
    *.tar|*.tar.gz|*.tar.bz2|*.tar.xz|*.tgz|*.tbz2|*.txz)
        tar -tf -- "$1" | head -n 20
        ;;
    *.zip)
        unzip -l -- "$1" | head -n 20
        ;;
    *.rar)
        unrar l -- "$1" | head -n 20
        ;;
    *.7z)
        7z l -- "$1" | head -n 20
        ;;
    *.pdf)
        pdftotext -- "$1" - | head -n 20
        ;;
    *.png|*.jpg|*.jpeg|*.gif|*.bmp|*.webp|*.heic|*.avif|*.ico|*.tiff|*.svg)
        chafa --size="${WIDTH}x${HEIGHT}" --colors=full -- "$1"
        ;;
    *)
        if [ -d "$1" ]; then
            ls -F --color=always -- "$1"
        elif [ -L "$1" ]; then
            ls -ld --color=always -- "$1"
        else
            MIME=$(file -bi -- "$1")
            case "$MIME" in
                image/*)
                    chafa --size="${WIDTH}x${HEIGHT}" --colors=full -- "$1"
                    ;;
                text/*|application/json*|application/javascript*)
                    bat --style="plain,numbers" --color=always --paging=never -- "$1"
                    ;;
                *)
                    file -b -- "$1"
                    ;;
            esac
        fi
        ;;
esac
