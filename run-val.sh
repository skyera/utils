#!/bin/bash
ts=$(date +"%Y%m%d_%H%M%S")
VALGRIND_OPTS="--leak-check=full --track-origins=yes --show-leak-kinds=all --log-file=valgrind_${ts}.log"
exec valgrind $VALGRIND_OPTS "$@"

