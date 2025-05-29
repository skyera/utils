#!/bin/sh
case "$1" in
    *.png|*.jpg|*.jpeg|*.gif|*.bmp)
        chafa --size=40x20 --colors=full "$1"
        ;;
    *)
        bat --style="plain,numbers" --color=always --paging=never "$1"
        ;;
esac
