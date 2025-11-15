#!/bin/bash
ts=$(date +"%Y%m%d_%H%M%S")
LOGFILE="valgrind_${ts}.log"
echo "Log file: $LOGFILE"
VALGRIND_OPTS="--leak-check=full --track-origins=yes --show-leak-kinds=all --log-file=$LOGFILE"
exec valgrind $VALGRIND_OPTS "$@"
